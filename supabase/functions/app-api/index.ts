import {createClient} from '@supabase/supabase-js';
import {ApiError, CONTRACT_VERSION, camel, deriveSecret, normalizePhone, optionalNumber, parseJsonValue, randomToken, requireString, routePath, safeEqual, sha256} from './helpers.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const DEFAULT_ALLOWED_ORIGINS = [
  'https://arrive-alive-virid.vercel.app',
  'https://cp.arrivealive.app',
];
const ALLOWED_ORIGINS = (Deno.env.get('APP_ALLOWED_ORIGINS') ?? DEFAULT_ALLOWED_ORIGINS.join(','))
  .split(',')
  .map((v) => v.trim())
  .filter(Boolean);
const SESSION_TTL_DAYS = Math.max(1, Math.min(90, Number(Deno.env.get('APP_SESSION_TTL_DAYS') ?? 30)));
if (!SUPABASE_URL || !SERVICE_KEY) console.error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required');
const db = createClient(SUPABASE_URL, SERVICE_KEY, {auth: {persistSession: false, autoRefreshToken: false}});

type AppUser = {id:number; phone:string; display_name:string; birth_year:number|null; role:'user'|'admin'; disabled_at:string|null};
type Identity = {user:AppUser; sessionId:string};

function cors(req: Request): Headers {
  const origin = req.headers.get('origin') ?? '';
  const allowed = !origin || ALLOWED_ORIGINS.includes(origin);
  const headers = new Headers({'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','Vary':'Origin'});
  if (origin && allowed) headers.set('Access-Control-Allow-Origin', origin);
  headers.set('Access-Control-Allow-Headers','authorization, content-type, idempotency-key, x-request-id');
  headers.set('Access-Control-Allow-Methods','GET, POST, PATCH, DELETE, OPTIONS');
  return headers;
}
function json(req:Request, body:unknown, status=200):Response { return new Response(JSON.stringify(body), {status, headers:cors(req)}); }
async function bodyJson(req:Request):Promise<Record<string,unknown>> {
  const length = Number(req.headers.get('content-length') ?? 0); if (length > 1_500_000) throw new ApiError(413,'Request body is too large');
  const type = req.headers.get('content-type') ?? ''; if (!type.includes('application/json')) throw new ApiError(415,'Content-Type must be application/json');
  try { const body = await req.json(); if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error(); return body; } catch { throw new ApiError(400,'Request body must be valid JSON'); }
}
function profile(user:Record<string,unknown>, token?:string) { const value = camel(user); delete value.pinHash; delete value.pinSalt; delete value.secretHash; delete value.secretSalt; delete value.hashIterations; return {...value, displayName:value.displayName ?? '', ...(token ? {token, tokenType:'Bearer'} : {})}; }
async function authenticate(req:Request, required=true):Promise<Identity|null> {
  const match = req.headers.get('authorization')?.match(/^Bearer\s+([A-Za-z0-9_-]{32,})$/i);
  if (!match) { if (required) throw new ApiError(401,'Authentication required','unauthorized'); return null; }
  const tokenHash = await sha256(match[1]);
  const {data,error} = await db.from('app_sessions').select('id,last_seen_at,users!inner(id,phone,display_name,birth_year,role,disabled_at)').eq('token_hash',tokenHash).is('revoked_at',null).gt('expires_at',new Date().toISOString()).maybeSingle();
  if (error || !data || !data.users || (data.users as unknown as AppUser).disabled_at) throw new ApiError(401,'Session is invalid or expired','unauthorized');
  if (Date.now()-Date.parse(data.last_seen_at)>300000) db.from('app_sessions').update({last_seen_at:new Date().toISOString()}).eq('id',data.id).then(()=>{});
  return {user:data.users as unknown as AppUser, sessionId:data.id};
}
function admin(identity:Identity|null):Identity { if (!identity || identity.user.role !== 'admin') throw new ApiError(403,'Administrator access required','forbidden'); return identity; }
async function audit(identity:Identity|null, action:string, entityType:string, entityId?:unknown, details:Record<string,unknown>={}) { await db.from('audit_log').insert({actor_user_id:identity?.user.id ?? null,action,entity_type:entityType,entity_id:entityId == null ? null : String(entityId),details}); }
async function issueSession(user:AppUser, req:Request) {
  const token=randomToken(32), token_hash=await sha256(token), expires_at=new Date(Date.now()+SESSION_TTL_DAYS*86400000).toISOString();
  const {error}=await db.from('app_sessions').insert({user_id:user.id,token_hash,expires_at,user_agent:(req.headers.get('user-agent')??'').slice(0,500)}); if(error) throw error; return token;
}
async function idempotent(identity:Identity, req:Request, path:string, payload:unknown, work:()=>Promise<{status:number;body:unknown}>):Promise<{status:number;body:unknown}> {
  const key=req.headers.get('idempotency-key'); if(!key) return work(); if(key.length>200) throw new ApiError(400,'Idempotency-Key is too long');
  const requestHash=await sha256(`${req.method}\n${path}\n${JSON.stringify(payload)}`);
  const {data}=await db.from('idempotency_keys').select('*').eq('user_id',identity.user.id).eq('key',key).maybeSingle();
  if(data){if(data.request_hash!==requestHash) throw new ApiError(409,'Idempotency key was reused with a different request'); if(data.response_status) return {status:data.response_status,body:data.response_body}; throw new ApiError(409,'Matching operation is still in progress');}
  const {error}=await db.from('idempotency_keys').insert({user_id:identity.user.id,key,method:req.method,path,request_hash:requestHash}); if(error) throw new ApiError(409,'Duplicate operation');
  try { const result=await work(); await db.from('idempotency_keys').update({response_status:result.status,response_body:result.body}).eq('user_id',identity.user.id).eq('key',key); return result; }
  catch(error){await db.from('idempotency_keys').delete().eq('user_id',identity.user.id).eq('key',key); throw error;}
}
function ensure(data:unknown,error:unknown):any { if(error) throw error; return data; }
function formatJourney(row:Record<string,unknown>){const value=camel(row);for(const key of ['vehicleDetails','assets','defects','path'])if(typeof value[key]!=='string')value[key]=JSON.stringify(value[key]??(key==='vehicleDetails'?{}:[]));return value;}
function formatIncident(row:Record<string,unknown>){return camel(row);}
function formatAgency(row:Record<string,unknown>){const value=camel(row);return {...value,phone:value.contact??null,violationCount:(value.metadata as any)?.violationCount??0,totalJourneys:(value.metadata as any)?.totalJourneys??0};}
function formatSpeedLimit(row:Record<string,unknown>){const value=camel(row);return {...value,vehicle_type:value.mode,limit_kmh:value.limitKph};}
function formatViolation(row:Record<string,unknown>){const value=camel(row);return {...value,lat:value.latitude??0,lng:value.longitude??0,timestamp:value.occurredAt,mode:(value.metadata as any)?.mode??'car',validated:value.status==='validated'?1:0,published:value.published?1:0,reportCount:(value.metadata as any)?.reportCount??1};}
function stable(body:Record<string,unknown>, prefix:string):string {
  const raw=String(body.stableId ?? body.localId ?? body.id ?? randomToken(16));
  const value=raw.replace(/[^A-Za-z0-9_.:-]/g,'').slice(0,100);
  return value.startsWith(`${prefix}-`)?value:`${prefix}-${value}`;
}
function choice(value:unknown, allowed:string[], fallback:string):string {
  const candidate=String(value??fallback);
  return allowed.includes(candidate)?candidate:fallback;
}
function journeyRow(body:Record<string,unknown>, userId:number) {
  return {
    stable_id:stable(body,'journey'),user_id:userId,agency_id:body.agencyId??null,
    mode:String(body.mode??'car'),vehicle_details:parseJsonValue(body.vehicleDetails,{}),
    assets:parseJsonValue(body.assets,[]),defects:parseJsonValue(body.defects,[]),
    driver_name:body.driverName??null,passenger_count:Number(body.passengerCount??1),
    start_lat:optionalNumber(body.startLat,'startLat',-90,90),
    start_lng:optionalNumber(body.startLng,'startLng',-180,180),
    end_lat:optionalNumber(body.endLat,'endLat',-90,90),
    end_lng:optionalNumber(body.endLng,'endLng',-180,180),
    start_time:body.startTime??new Date().toISOString(),end_time:body.endTime??null,
    status:choice(body.status,['active','completed','cancelled'],'active'),
    max_speed:Number(body.maxSpeed??0),avg_speed:Number(body.avgSpeed??0),
    distance:Number(body.distance??0),violation_count:Number(body.violationCount??0),
    score:Number(body.score??100),path:parseJsonValue(body.path,[]),
    client_updated_at:body.updatedAt??null,version:Number(body.version??1),
    deleted_at:body.deletedAt??null
  };
}
function incidentRow(body:Record<string,unknown>, userId:number) {
  return {
    stable_id:stable(body,'incident'),reporter_user_id:userId,
    type:requireString(body.type,'type',2,50),
    description:body.description?requireString(body.description,'description',1,1000):null,
    lat:optionalNumber(body.lat,'lat',-90,90),lng:optionalNumber(body.lng,'lng',-180,180),
    vehicle_reg:body.vehicleReg??null,driver_name:body.driverName??null,
    status:choice(body.status,['active','resolved','removed'],'active'),
    confirmation_count:Number(body.confirmationCount??0),
    not_there_count:Number(body.notThereCount??0),
    last_confirmed_at:body.lastConfirmedAt??null,resolved_at:body.resolvedAt??null,
    client_updated_at:body.updatedAt??null,version:Number(body.version??1),
    deleted_at:body.deletedAt??null
  };
}
function violationRow(body:Record<string,unknown>, userId:number) { return {stable_id:stable(body,'violation'),journey_id:Number(body.journeyId),user_id:userId,agency_id:body.agencyId??null,type:requireString(body.type??'speeding','type',2,50),speed:Number(body.speed??0),speed_limit:Number(body.speedLimit??0),latitude:optionalNumber(body.latitude??body.lat,'latitude',-90,90),longitude:optionalNumber(body.longitude??body.lng,'longitude',-180,180),occurred_at:body.timestamp??body.occurredAt??new Date().toISOString(),vehicle_reg:body.vehicleReg??null,route:body.route??null,metadata:{...(typeof body.metadata==='object'&&body.metadata?body.metadata as Record<string,unknown>:{}),mode:body.mode??'car',reportCount:Number(body.reportCount??1)},client_updated_at:body.updatedAt??null,version:Number(body.version??1)}; }
function syncRecord(value:Record<string,unknown>):Record<string,unknown> {
  return {...value,remoteId:value.id,id:value.stableId??String(value.id)};
}
function publicReportSnapshot(input:unknown):Record<string,unknown> {
  if(!input||typeof input!=='object'||Array.isArray(input))throw new ApiError(400,'snapshot object is required');
  const source=input as Record<string,any>,agency=source.agency??{},metrics=source.metrics??{};
  const modes=['car','bus','lorry','motorbike'];
  const cleanText=(value:unknown,max=160)=>String(value??'').replace(/[\u0000-\u001f\u007f]/g,' ').trim().slice(0,max);
  const cleanNumber=(value:unknown,min=0,max=100000)=>Math.max(min,Math.min(max,Number.isFinite(Number(value))?Number(value):0));
  const breakdown=Array.isArray(source.vehicleBreakdown)?source.vehicleBreakdown.slice(0,4).map((item:any)=>({
    mode:modes.includes(String(item?.mode))?String(item.mode):'car',
    vehicles:cleanNumber(item?.vehicles),journeys:cleanNumber(item?.journeys),violations:cleanNumber(item?.violations),
    maxSpeed:cleanNumber(item?.maxSpeed,0,400),averageSpeed:cleanNumber(item?.averageSpeed,0,400),speedLimit:cleanNumber(item?.speedLimit,0,300),
  })):[];
  const journeys=Array.isArray(source.journeys)?source.journeys.slice(0,100).map((item:any)=>({
    id:cleanText(item?.id,100),mode:modes.includes(String(item?.mode))?String(item.mode):'car',
    endedAt:item?.endedAt?cleanText(item.endedAt,40):null,distanceKm:cleanNumber(item?.distanceKm,0,100000),
    maxSpeed:cleanNumber(item?.maxSpeed,0,400),averageSpeed:cleanNumber(item?.averageSpeed,0,400),violations:cleanNumber(item?.violations),
  })):[];
  const violations=Array.isArray(source.violations)?source.violations.slice(0,100).map((item:any)=>({
    mode:modes.includes(String(item?.mode))?String(item.mode):'car',plate:cleanText(item?.plate,32),
    speed:cleanNumber(item?.speed,0,400),limit:cleanNumber(item?.limit,0,300),route:cleanText(item?.route,160),time:cleanText(item?.time,80),
  })):[];
  const safe={
    reportVersion:1,generatedAt:new Date().toISOString(),
    agency:{id:cleanText(agency.id,100),name:cleanText(agency.name,120),region:cleanText(agency.region,120),safetyScore:cleanNumber(agency.safetyScore,0,100),trusted:Boolean(agency.trusted)},
    metrics:{vehicles:cleanNumber(metrics.vehicles),journeys:cleanNumber(metrics.journeys),violations:cleanNumber(metrics.violations),safetyScore:cleanNumber(metrics.safetyScore,0,100)},
    vehicleBreakdown:breakdown,journeys,violations,
  };
  if(!safe.agency.id||safe.agency.name.length<2)throw new ApiError(400,'A valid agency is required');
  if(JSON.stringify(safe).length>500000)throw new ApiError(413,'Public report snapshot is too large');
  return safe;
}
async function upsertOwned(table:string, row:Record<string,unknown>, ownerColumn:string, ownerId:number) {
  const {data:existing,error:readError}=await db.from(table).select(`id,${ownerColumn},version,client_updated_at`).eq('stable_id',row.stable_id).maybeSingle();
  ensure(existing,readError);
  if(existing&&Number(existing[ownerColumn])!==ownerId)throw new ApiError(403,'Record belongs to another account');
  if(existing){
    const incomingVersion=Number(row.version??1),storedVersion=Number(existing.version??1);
    const incomingTime=Date.parse(String(row.client_updated_at??''))||0;
    const storedTime=Date.parse(String(existing.client_updated_at??''))||0;
    if(incomingVersion<storedVersion||(incomingVersion===storedVersion&&incomingTime<storedTime))return existing;
  }
  const {data,error}=await db.from(table).upsert(row,{onConflict:'stable_id'}).select('*').single();
  return ensure(data,error);
}

async function snapshot(identity:Identity, since?:string) {
  const isAdmin=identity.user.role==='admin';
  let usersQ=db.from('users').select('id,stable_id,phone,display_name,birth_year,role,photo_path,version,created_at,updated_at'); if(!isAdmin) usersQ=usersQ.eq('id',identity.user.id);
  let journeysQ=db.from('journeys').select('*'); if(!isAdmin) journeysQ=journeysQ.eq('user_id',identity.user.id); if(since) journeysQ=journeysQ.gt('updated_at',since);
  let incidentsQ=db.from('incidents').select('*'); if(since) incidentsQ=incidentsQ.gt('updated_at',since);
  const [users,journeys,incidents,agencies,limits]=await Promise.all([usersQ,journeysQ,incidentsQ,db.from('agencies').select('*').is('deleted_at',null),db.from('speed_limits').select('*').is('deleted_at',null)]);
  const rows=(result:any)=>ensure(result.data,result.error).map(camel);
  const userRows=rows(users).map(syncRecord);
  return {schemaVersion:1,revision:Date.now(),updatedAt:new Date().toISOString(),collections:{
    users:userRows,profiles:userRows,
    journeys:ensure(journeys.data,journeys.error).map(formatJourney).map(syncRecord),
    incidents:ensure(incidents.data,incidents.error).map(formatIncident).map(syncRecord),
    agencies:ensure(agencies.data,agencies.error).map(formatAgency).map(syncRecord),
    speedLimits:ensure(limits.data,limits.error).map(formatSpeedLimit).map(syncRecord)
  }};
}

async function handle(req:Request):Promise<Response> {
  if(req.method==='OPTIONS'){const origin=req.headers.get('origin')??''; if(origin&&!ALLOWED_ORIGINS.includes(origin)) return json(req,{error:'Origin is not allowed'},403); return new Response(null,{status:204,headers:cors(req)});}
  const path=routePath(req.url), url=new URL(req.url), method=req.method;
  if(path==='/health'&&method==='GET') return json(req,{ok:true,contractVersion:CONTRACT_VERSION,persistence:{durable:true,adapter:'supabase-postgres'}});
  const publicReportMatch=path.match(/^\/api\/public-reports\/([a-z0-9_-]{12,80})$/);
  if(publicReportMatch&&method==='GET'){
    const {data,error}=await db.from('public_agency_reports').select('slug,snapshot,created_at,expires_at').eq('slug',publicReportMatch[1]).is('revoked_at',null).maybeSingle();
    if(error||!data||(data.expires_at&&Date.parse(data.expires_at)<=Date.now()))throw new ApiError(404,'Public report not found','not_found');
    return json(req,{slug:data.slug,snapshot:data.snapshot,createdAt:data.created_at,expiresAt:data.expires_at});
  }
  if(path==='/api/auth/register'&&method==='POST'){
    const body=await bodyJson(req),phone=normalizePhone(body.phone),pin=requireString(body.pin,'pin',4,12),secret=requireString(body.secretWord,'secretWord',3,100),birth=optionalNumber(body.birthYear,'birthYear',1900,new Date().getUTCFullYear());
    const pinSalt=randomToken(16),secretSalt=randomToken(16),iterations=210000;
    const {data,error}=await db.from('users').insert({phone,birth_year:birth,pin_hash:await deriveSecret(pin,pinSalt,iterations),pin_salt:pinSalt,secret_hash:await deriveSecret(secret.toLocaleLowerCase(),secretSalt,iterations),secret_salt:secretSalt,hash_iterations:iterations,display_name:body.displayName?requireString(body.displayName,'displayName',2,80):''}).select('id,phone,display_name,birth_year,role,disabled_at').single();
    if(error?.code==='23505') throw new ApiError(409,'An account with this phone already exists'); const user=ensure(data,error) as AppUser,token=await issueSession(user,req); await audit({user,sessionId:''},'register','user',user.id); return json(req,profile(user as unknown as Record<string,unknown>,token),201);
  }
  if(path==='/api/auth/login'&&method==='POST'){
    const body=await bodyJson(req),phone=normalizePhone(body.phone),pin=requireString(body.pin,'pin',4,12);
    const {data}=await db.from('users').select('*').eq('phone',phone).maybeSingle();
    if(!data){await new Promise(r=>setTimeout(r,250));throw new ApiError(401,'Incorrect phone or PIN','invalid_credentials');}
    const candidate=await deriveSecret(pin,data.pin_salt,data.hash_iterations); if(!safeEqual(candidate,data.pin_hash)||data.disabled_at){await new Promise(r=>setTimeout(r,250));throw new ApiError(401,'Incorrect phone or PIN','invalid_credentials');}
    const token=await issueSession(data as AppUser,req); await db.from('users').update({last_login_at:new Date().toISOString()}).eq('id',data.id); await audit({user:data as AppUser,sessionId:''},'login','session'); return json(req,profile(data,token));
  }
  if(path==='/api/auth/reset-pin'&&method==='POST'){
    const body=await bodyJson(req),phone=normalizePhone(body.phone),secret=requireString(body.secretWord,'secretWord',3,100).toLocaleLowerCase(),newPin=requireString(body.newPin,'newPin',4,12);
    const {data}=await db.from('users').select('*').eq('phone',phone).maybeSingle(); if(!data) throw new ApiError(400,'Secret word does not match');
    const valid=safeEqual(await deriveSecret(secret,data.secret_salt,data.hash_iterations),data.secret_hash); if(!valid) throw new ApiError(400,'Secret word does not match');
    const salt=randomToken(16); ensure(null,(await db.from('users').update({pin_salt:salt,pin_hash:await deriveSecret(newPin,salt,data.hash_iterations)}).eq('id',data.id)).error); await db.from('app_sessions').update({revoked_at:new Date().toISOString()}).eq('user_id',data.id); await audit({user:data as AppUser,sessionId:''},'reset_pin','user',data.id); return json(req,{ok:true});
  }
  const identity=await authenticate(req,true) as Identity;
  if(path==='/api/public-reports'&&method==='POST'){
    admin(identity);const body=await bodyJson(req),safe=publicReportSnapshot(body.snapshot),slug=randomToken(18).toLowerCase();
    const {data,error}=await db.from('public_agency_reports').insert({slug,agency_stable_id:(safe.agency as any).id,snapshot:safe,created_by:identity.user.id}).select('slug,created_at').single();
    await audit(identity,'publish','public_agency_report',(safe.agency as any).id,{slug});
    const created=ensure(data,error);return json(req,{slug:created.slug,createdAt:created.created_at},201);
  }
  if(path==='/api/auth/logout'&&method==='POST'){await db.from('app_sessions').update({revoked_at:new Date().toISOString()}).eq('id',identity.sessionId);return json(req,{ok:true});}
  if(path==='/api/profile'&&method==='GET') return json(req,profile(identity.user as unknown as Record<string,unknown>));
  if(path==='/api/profile'&&method==='PATCH'){const body=await bodyJson(req),update:any={};if(body.displayName!==undefined)update.display_name=requireString(body.displayName,'displayName',2,80);if(body.phone!==undefined)update.phone=normalizePhone(body.phone);const {data,error}=await db.from('users').update(update).eq('id',identity.user.id).select('id,phone,display_name,birth_year,role,photo_path').single();if(error?.code==='23505')throw new ApiError(409,'Phone already in use');await audit(identity,'update','profile',identity.user.id);return json(req,profile(ensure(data,error)));}
  if(path==='/api/profile/photo'&&method==='POST'){const form=await req.formData(),file=form.get('photo');if(!(file instanceof File))throw new ApiError(400,'photo file is required');if(file.size>2097152||!['image/jpeg','image/png','image/webp'].includes(file.type))throw new ApiError(400,'Photo must be JPEG, PNG or WebP and no larger than 2 MB');const ext={'image/jpeg':'jpg','image/png':'png','image/webp':'webp'}[file.type];const objectPath=`${identity.user.id}/${randomToken(12)}.${ext}`;const {error}=await db.storage.from('profile-photos').upload(objectPath,file,{contentType:file.type,upsert:false});ensure(null,error);await db.from('users').update({photo_path:objectPath}).eq('id',identity.user.id);const signed=await db.storage.from('profile-photos').createSignedUrl(objectPath,3600);return json(req,{photoPath:objectPath,photoUrl:signed.data?.signedUrl??null});}
  if(path==='/api/sync'&&(method==='GET'||method==='POST')){if(method==='GET')return json(req,{contractVersion:CONTRACT_VERSION,snapshot:await snapshot(identity,url.searchParams.get('since')??undefined),persistence:{durable:true,adapter:'supabase-postgres',message:'Durably synchronized with Supabase.'}});const body=await bodyJson(req);if(body.operation==='pull')return json(req,{contractVersion:CONTRACT_VERSION,snapshot:await snapshot(identity,String(body.since??'')||undefined),persistence:{durable:true,adapter:'supabase-postgres',message:'Durable pull completed.'}});if(body.operation!=='merge'&&body.operation!=='push')throw new ApiError(400,'Expected sync merge, push, or pull operation');const collections=(body.snapshot as any)?.collections??body.collections;if(!collections||typeof collections!=='object')throw new ApiError(400,'Snapshot collections are required');const result=await idempotent(identity,req,path,body,async()=>{for(const item of collections.journeys??[]){await upsertOwned('journeys',journeyRow(item,identity.user.id),'user_id',identity.user.id);}for(const item of collections.incidents??[]){await upsertOwned('incidents',incidentRow(item,identity.user.id),'reporter_user_id',identity.user.id);}if(identity.user.role==='admin'){for(const item of collections.agencies??[]){await db.from('agencies').upsert({stable_id:String(item.stableId??item.id),name:item.name,type:item.type??null,region:item.region??null,contact:item.phone??item.contact??null,safety_score:Number(item.safetyScore??item.score??0),verified:Boolean(item.verified??item.trusted),metadata:item.metadata??{}},{onConflict:'stable_id'});}for(const item of collections.speedLimits??[]){const mode=String(item.mode??item.vehicle_type??item.id);const limit=Number(item.limitKph??item.limit_kmh??item.limit);if(mode&&Number.isFinite(limit))await db.from('speed_limits').upsert({stable_id:String(item.stableId??item.id??`speed-${mode}`),mode,limit_kph:limit},{onConflict:'mode'});}}await db.from('sync_state').upsert({user_id:identity.user.id,last_push_at:new Date().toISOString(),revision:Date.now()});return{status:200,body:{contractVersion:CONTRACT_VERSION,snapshot:await snapshot(identity),persistence:{durable:true,adapter:'supabase-postgres',message:'Durably synchronized with Supabase.'}}};});return json(req,result.body,result.status);}
  if(path==='/api/journeys'&&method==='POST'){const body=await bodyJson(req);const result=await idempotent(identity,req,path,body,async()=>{const {data,error}=await db.from('journeys').insert(journeyRow(body,identity.user.id)).select('*').single();const value=formatJourney(ensure(data,error));await audit(identity,'create','journey',value.id);return{status:201,body:value};});return json(req,result.body,result.status);}
  if(path==='/api/journeys'&&method==='GET'){const {data,error}=await db.from('journeys').select('*').eq('user_id',identity.user.id).is('deleted_at',null).order('start_time',{ascending:false});return json(req,ensure(data,error).map(formatJourney));}
  let match=path.match(/^\/api\/journeys\/(\d+)$/);if(match&&method==='PATCH'){const body=await bodyJson(req),id=Number(match[1]);const allowed:any={};const map:any={status:'status',endTime:'end_time',maxSpeed:'max_speed',avgSpeed:'avg_speed',distance:'distance',violationCount:'violation_count',score:'score',path:'path',updatedAt:'client_updated_at',version:'version'};for(const [key,column]of Object.entries(map))if(body[key]!==undefined)allowed[column as string]=key==='path'?parseJsonValue(body[key],[]):body[key];let query=db.from('journeys').update(allowed).eq('id',id);if(identity.user.role!=='admin')query=query.eq('user_id',identity.user.id);const {data,error}=await query.select('*').maybeSingle();if(error||!data)throw new ApiError(404,'Journey not found');return json(req,formatJourney(data));}
  match=path.match(/^\/api\/journeys\/user\/(\d+)$/);if(match&&method==='GET'){const userId=Number(match[1]);if(userId!==identity.user.id)admin(identity);const {data,error}=await db.from('journeys').select('*').eq('user_id',userId).is('deleted_at',null).order('start_time',{ascending:false});return json(req,ensure(data,error).map(formatJourney));}
  if(path==='/api/incidents'&&method==='GET'){let q=db.from('incidents').select('*').is('deleted_at',null).order('updated_at',{ascending:false});if(identity.user.role!=='admin')q=q.eq('status','active');const {data,error}=await q.limit(500);return json(req,ensure(data,error).map(formatIncident));}
  if(path==='/api/incidents'&&method==='POST'){const body=await bodyJson(req);const result=await idempotent(identity,req,path,body,async()=>{const row=incidentRow(body,identity.user.id);if(row.lat===null||row.lng===null)throw new ApiError(400,'lat and lng are required');const {data,error}=await db.from('incidents').insert(row).select('*').single();const value=formatIncident(ensure(data,error));return{status:201,body:value};});return json(req,result.body,result.status);}
  match=path.match(/^\/api\/incidents\/(\d+)\/confirm$/);if(match&&method==='POST'){const body=await bodyJson(req);if(typeof body.stillThere!=='boolean')throw new ApiError(400,'stillThere must be boolean');const {data,error}=await db.rpc('confirm_incident',{p_incident_id:Number(match[1]),p_user_id:identity.user.id,p_still_there:body.stillThere,p_idempotency_key:req.headers.get('idempotency-key')});return json(req,formatIncident(ensure(data,error)));}
  if(path==='/api/violations'&&method==='POST'){const body=await bodyJson(req);const result=await idempotent(identity,req,path,body,async()=>{const {data:errorJourney}=await db.from('journeys').select('user_id').eq('id',Number(body.journeyId)).eq('user_id',identity.user.id).maybeSingle();if(!errorJourney)throw new ApiError(404,'Journey not found');const {data,error}=await db.from('violations').insert(violationRow(body,identity.user.id)).select('*').single();return{status:201,body:formatViolation(ensure(data,error))};});return json(req,result.body,result.status);}
  if(path==='/api/violations'&&method==='GET'){let q=db.from('violations').select('*').is('deleted_at',null).order('occurred_at',{ascending:false});if(url.searchParams.get('published')==='true')q=q.eq('published',true);else{admin(identity);if(url.searchParams.get('pending')==='true')q=q.eq('status','pending');}const {data,error}=await q.limit(500);return json(req,ensure(data,error).map(formatViolation));}
  match=path.match(/^\/api\/violations\/(\d+)\/(validate|dismiss)$/);if(match&&method==='PATCH'){admin(identity);const status=match[2]==='validate'?'validated':'dismissed';const {data,error}=await db.from('violations').update({status,published:status==='validated'}).eq('id',Number(match[1])).select('*').single();await audit(identity,status,'violation',match[1]);return json(req,formatViolation(ensure(data,error)));}
  if(path==='/api/agencies'&&method==='GET'){const {data,error}=await db.from('agencies').select('*').is('deleted_at',null).order('name');return json(req,ensure(data,error).map(formatAgency));}
  if(path==='/api/agencies'&&method==='POST'){admin(identity);const body=await bodyJson(req),name=requireString(body.name,'name',2,120);const row={stable_id:stable(body,'agency'),name,type:body.type??null,region:body.region??null,contact:body.phone??body.contact??null,safety_score:Number(body.safetyScore??0),verified:Boolean(body.verified),metadata:body.metadata??{}};const {data,error}=await db.from('agencies').insert(row).select('*').single();await audit(identity,'create','agency',data?.id);return json(req,formatAgency(ensure(data,error)),201);}
  match=path.match(/^\/api\/agencies\/(\d+)$/);if(match&&method==='PATCH'){admin(identity);const body=await bodyJson(req),row:any={};const fields:any={name:'name',type:'type',region:'region',phone:'contact',contact:'contact',safetyScore:'safety_score',verified:'verified',metadata:'metadata'};for(const [key,column]of Object.entries(fields))if(body[key]!==undefined)row[column as string]=body[key];if(row.name!==undefined)row.name=requireString(row.name,'name',2,120);const {data,error}=await db.from('agencies').update(row).eq('id',Number(match[1])).select('*').single();await audit(identity,'update','agency',match[1]);return json(req,formatAgency(ensure(data,error)));}
  if(path==='/api/speed-limits'&&method==='GET'){const {data,error}=await db.from('speed_limits').select('*').is('deleted_at',null);return json(req,ensure(data,error).map(formatSpeedLimit));}
  if(path==='/api/admin/speed-limits'&&method==='POST'){admin(identity);const body=await bodyJson(req),mode=requireString(body.mode??body.vehicle_type,'mode',2,30),limit=Math.round(optionalNumber(body.limit??body.limit_kmh,'limit',1,300)??0);const {data,error}=await db.from('speed_limits').upsert({stable_id:`speed-${mode}`,mode,limit_kph:limit},{onConflict:'mode'}).select('*').single();await audit(identity,'upsert','speed_limit',mode);return json(req,formatSpeedLimit(ensure(data,error)));}
  if(path==='/api/settings'&&method==='PATCH'){admin(identity);const body=await bodyJson(req),limits=body.speedLimits;if(!limits||typeof limits!=='object'||Array.isArray(limits))throw new ApiError(400,'speedLimits object is required');for(const [mode,value]of Object.entries(limits)){const limit=optionalNumber(value,mode,1,300);await db.from('speed_limits').upsert({stable_id:`speed-${mode}`,mode,limit_kph:limit},{onConflict:'mode'});}await audit(identity,'update','speed_limits');return json(req,{ok:true});}
  if(path==='/api/users'&&method==='GET'){admin(identity);const {data,error}=await db.from('users').select('id,stable_id,phone,display_name,birth_year,role,disabled_at,last_login_at,version,created_at,updated_at').order('created_at',{ascending:false}).limit(500);return json(req,ensure(data,error).map(camel));}
  if(path==='/api/stats'&&method==='GET'){admin(identity);const [users,journeys,incidents,activeIncidents,violations,pendingViolations]=await Promise.all([db.from('users').select('*',{count:'exact',head:true}),db.from('journeys').select('*',{count:'exact',head:true}),db.from('incidents').select('*',{count:'exact',head:true}),db.from('incidents').select('*',{count:'exact',head:true}).eq('status','active'),db.from('violations').select('*',{count:'exact',head:true}),db.from('violations').select('*',{count:'exact',head:true}).eq('status','pending')]);return json(req,{totalUsers:users.count??0,totalJourneys:journeys.count??0,totalIncidents:incidents.count??0,totalViolations:violations.count??0,users:users.count??0,journeys:journeys.count??0,activeIncidents:activeIncidents.count??0,pendingViolations:pendingViolations.count??0});}
  if(path==='/api/admin/sync-health'&&method==='GET'){admin(identity);const {data,error}=await db.from('sync_state').select('*,users(phone,display_name)').order('updated_at',{ascending:false}).limit(200);return json(req,{durable:true,adapter:'supabase-postgres',clients:ensure(data,error).map(camel)});}
  throw new ApiError(404,'Route not found','not_found');
}

Deno.serve(async(req)=>{try{return await handle(req);}catch(error){if(error instanceof ApiError)return json(req,{error:error.message,code:error.code},error.status);console.error(error);return json(req,{error:'Internal server error',code:'internal_error'},500);}});
