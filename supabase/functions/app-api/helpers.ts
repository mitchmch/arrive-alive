export const CONTRACT_VERSION = 2;
export const COLLECTIONS = ['users', 'profiles', 'journeys', 'incidents', 'agencies', 'speedLimits'] as const;

const encoder = new TextEncoder();
export function bytesToHex(bytes: Uint8Array): string { return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join(''); }
export function bytesToBase64Url(bytes: Uint8Array): string {
  let value = ''; for (const byte of bytes) value += String.fromCharCode(byte);
  return btoa(value).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}
export function randomToken(bytes = 32): string { const value = new Uint8Array(bytes); crypto.getRandomValues(value); return bytesToBase64Url(value); }
export async function sha256(value: string): Promise<string> { return bytesToHex(new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value)))); }
export async function deriveSecret(secret: string, salt: string, iterations = 210000): Promise<string> {
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({name: 'PBKDF2', hash: 'SHA-256', salt: encoder.encode(salt), iterations}, key, 256);
  return bytesToHex(new Uint8Array(bits));
}
export function safeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false; let difference = 0;
  for (let index = 0; index < left.length; index++) difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  return difference === 0;
}
export function normalizePhone(value: unknown): string {
  const phone = String(value ?? '').trim();
  if (phone === 'admin') return phone;
  const normalized = phone.replace(/[\s()-]/g, '');
  if (!/^\+?[0-9]{8,15}$/.test(normalized)) throw new ApiError(400, 'Enter a valid phone number');
  return normalized;
}
export function requireString(value: unknown, name: string, min = 1, max = 500): string {
  if (typeof value !== 'string') throw new ApiError(400, `${name} must be a string`);
  const result = value.trim(); if (result.length < min || result.length > max) throw new ApiError(400, `${name} must be ${min}-${max} characters`); return result;
}
export function optionalNumber(value: unknown, name: string, min: number, max: number): number | null {
  if (value === null || value === undefined || value === '') return null; const result = Number(value);
  if (!Number.isFinite(result) || result < min || result > max) throw new ApiError(400, `${name} is out of range`); return result;
}
export function parseJsonValue(value: unknown, fallback: unknown): unknown {
  if (value === undefined || value === null || value === '') return fallback;
  if (typeof value !== 'string') return value;
  try { return JSON.parse(value); } catch { throw new ApiError(400, 'A JSON field is malformed'); }
}
export function camel(row: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(row)) out[key.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase())] = value;
  if ('createdAt' in out && !('timestamp' in out)) out.timestamp = out.createdAt;
  return out;
}
export function routePath(url: string): string {
  let path = new URL(url).pathname.replace(/\/+$/, '') || '/';
  const marker = '/app-api'; const at = path.indexOf(marker); if (at >= 0) path = path.slice(at + marker.length) || '/';
  return path;
}
export class ApiError extends Error { constructor(public status: number, message: string, public code = 'request_error') { super(message); } }

export type RawSpeedSample = {
  timestamp?: unknown; recordedAt?: unknown; speedKph?: unknown; speedKmh?: unknown;
  accuracyM?: unknown; latitude?: unknown; longitude?: unknown;
};
export type SafetySample = {
  id:string; sequence:number; recordedAt:string; speedKph:number;
  speedLimitKph:number; accuracyM:number|null; latitude:number|null;
  longitude:number|null; accepted:boolean; rejectionReason:string|null;
};
export type ViolationEpisode = {
  id:string; startedAt:string; endedAt:string; sampleCount:number;
  peakSpeedKph:number; averageSpeedKph:number; durationSeconds:number;
  speedLimitKph:number; overByKph:number;
};

function round(value:number, places=2):number {
  const scale=10**places;
  return Math.round((value+Number.EPSILON)*scale)/scale;
}
function median(values:number[]):number {
  if(!values.length)return 0;
  const sorted=[...values].sort((a,b)=>a-b), middle=Math.floor(sorted.length/2);
  return sorted.length%2?sorted[middle]:(sorted[middle-1]+sorted[middle])/2;
}
export async function stableUuid(namespace:string,key:string):Promise<string> {
  const hash=await crypto.subtle.digest('SHA-256',encoder.encode(`${namespace}\n${key}`));
  const bytes=new Uint8Array(hash).slice(0,16);
  bytes[6]=(bytes[6]&0x0f)|0x50;
  bytes[8]=(bytes[8]&0x3f)|0x80;
  const hex=bytesToHex(bytes);
  return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20)}`;
}

export async function assessJourneySamples(
  journeyStableId:string,
  rawSamples:RawSpeedSample[],
  speedLimitKph:number,
):Promise<{samples:SafetySample[];episodes:ViolationEpisode[];assessment:Record<string,unknown>}> {
  if(!Number.isFinite(speedLimitKph)||speedLimitKph<1||speedLimitKph>300)throw new ApiError(400,'A valid admin speed limit is required');
  if(!Array.isArray(rawSamples)||rawSamples.length>20000)throw new ApiError(400,'samples must be an array of at most 20,000 items');
  const ordered=rawSamples.map((sample,index)=>({sample,index,time:Date.parse(String(sample.recordedAt??sample.timestamp??''))}))
    .sort((a,b)=>(a.time||0)-(b.time||0)||a.index-b.index);
  const samples:SafetySample[]=[];
  for(let sequence=0;sequence<ordered.length;sequence++){
    const {sample,time}=ordered[sequence],speed=Number(sample.speedKph??sample.speedKmh),accuracy=sample.accuracyM==null?null:Number(sample.accuracyM);
    let rejectionReason:string|null=null;
    if(!Number.isFinite(time))rejectionReason='invalid_timestamp';
    else if(!Number.isFinite(speed)||speed<0||speed>220)rejectionReason='implausible_speed';
    else if(accuracy!==null&&(!Number.isFinite(accuracy)||accuracy>65||accuracy<0))rejectionReason='low_location_accuracy';
    const recordedAt=Number.isFinite(time)?new Date(time).toISOString():new Date(0).toISOString();
    samples.push({
      id:await stableUuid('speed-sample-v1',`${journeyStableId}:${sequence}:${recordedAt}`),
      sequence,recordedAt,speedKph:round(Number.isFinite(speed)?Math.max(0,Math.min(300,speed)):0),
      speedLimitKph:round(speedLimitKph),accuracyM:Number.isFinite(accuracy as number)?round(accuracy as number):null,
      latitude:Number.isFinite(Number(sample.latitude))?Number(sample.latitude):null,
      longitude:Number.isFinite(Number(sample.longitude))?Number(sample.longitude):null,
      accepted:!rejectionReason,rejectionReason,
    });
  }
  const accepted=samples.filter(sample=>sample.accepted);
  const candidates:SafetySample[][]=[];let current:SafetySample[]=[];
  for(const sample of accepted){
    const previous=current.at(-1);
    if(sample.speedKph>speedLimitKph+2){
      if(previous&&Date.parse(sample.recordedAt)-Date.parse(previous.recordedAt)>10000){
        if(current.length) candidates.push(current);
        current=[];
      }
      current.push(sample);
    }else if(current.length){candidates.push(current);current=[];}
  }
  if(current.length)candidates.push(current);
  const episodes:ViolationEpisode[]=[];
  for(const group of candidates){
    const duration=Math.max(0,Math.round((Date.parse(group.at(-1)!.recordedAt)-Date.parse(group[0].recordedAt))/1000));
    if(group.length<3&&duration<2)continue;
    const peak=Math.max(...group.map(item=>item.speedKph));
    episodes.push({
      id:await stableUuid('violation-episode-v1',`${journeyStableId}:${group[0].recordedAt}`),
      startedAt:group[0].recordedAt,endedAt:group.at(-1)!.recordedAt,
      sampleCount:group.length,peakSpeedKph:round(peak),
      averageSpeedKph:round(group.reduce((sum,item)=>sum+item.speedKph,0)/group.length),
      durationSeconds:duration,speedLimitKph:round(speedLimitKph),
      overByKph:round(peak-speedLimitKph),
    });
  }
  const speeds=accepted.map(item=>item.speedKph);
  const peak=speeds.length?Math.max(...speeds):0;
  const average=speeds.length?speeds.reduce((sum,value)=>sum+value,0)/speeds.length:0;
  const duration=accepted.length>1?Math.max(0,Math.round((Date.parse(accepted.at(-1)!.recordedAt)-Date.parse(accepted[0].recordedAt))/1000)):0;
  const maxOver=episodes.length?Math.max(...episodes.map(item=>item.overByKph)):0;
  const evidenceConfidence=Math.min(1,accepted.length/30)*Math.min(1,Math.max(duration,1)/120);
  const resultType=episodes.length?'violator':'within_limit';
  const reasons=episodes.length
    ? [`${episodes.length} sustained speeding episode${episodes.length===1?'':'s'} detected`,`Peak speed was ${round(maxOver,1)} km/h above the admin limit`]
    : accepted.length<3
      ? ['No sustained violation detected','Limited accepted telemetry']
      : ['No sustained violation detected',`${accepted.length} accepted telemetry samples were within the configured tolerance`];
  const status=accepted.length<3?'insufficient_evidence':episodes.length?'avoid':'trusted';
  const deterministicSummary=episodes.length
    ? `${episodes.length} sustained speed violation${episodes.length===1?' was':'s were'} detected. Peak ${round(peak,1)} km/h against a ${round(speedLimitKph,1)} km/h limit.`
    : `No sustained speed violation was detected in ${accepted.length} accepted samples against a ${round(speedLimitKph,1)} km/h limit.`;
  return {samples,episodes,assessment:{
    status,resultType,speedLimitKph:round(speedLimitKph),acceptedSampleCount:accepted.length,
    rejectedSampleCount:samples.length-accepted.length,episodeCount:episodes.length,
    peakSpeedKph:round(peak),averageSpeedKph:round(average),durationSeconds:duration,
    maxOverByKph:round(maxOver),confidence:round(evidenceConfidence,4),reasons,deterministicSummary,
  }};
}

export function robustWeightedSpeed(
  telemetryKph:number,
  reports:Array<{reporterId:string|number;speedKph:number}>,
):{valueKph:number;independentReporterCount:number;outlierCount:number;cappedReportCount:number;details:Record<string,unknown>} {
  const unique=new Map<string,number>();
  for(const report of reports){
    const id=String(report.reporterId),value=Number(report.speedKph);
    if(!unique.has(id)&&Number.isFinite(value)&&value>=0&&value<=300)unique.set(id,value);
  }
  const raw=[telemetryKph,...unique.values()],center=median(raw);
  const mad=median(raw.map(value=>Math.abs(value-center)));
  const band=Math.max(15,3*mad);
  let outlierCount=0,cappedReportCount=0,weighted=telemetryKph,totalWeight=1;
  for(const value of unique.values()){
    const telemetryCapped=Math.max(telemetryKph-25,Math.min(telemetryKph+25,value));
    const robustCapped=Math.max(center-band,Math.min(center+band,telemetryCapped));
    if(Math.abs(value-center)>band)outlierCount++;
    if(robustCapped!==value)cappedReportCount++;
    weighted+=robustCapped*.35;
    totalWeight+=.35;
    if(totalWeight>=2.5)break;
  }
  return {valueKph:round(weighted/totalWeight),independentReporterCount:unique.size,outlierCount,cappedReportCount,
    details:{method:'telemetry-anchor + unique-reporter winsorized weighted mean',telemetryWeight:1,reportWeight:.35,maxReportWeight:1.5,center:round(center),mad:round(mad),bandKph:round(band)}};
}

export const ROLLUP_THRESHOLDS={minimumJourneys:10,minimumDistinctUsers:5,minimumDurationSeconds:3600,avoidMinimumViolationJourneys:3,avoidRate:0.2,trustedMaximumViolationRate:0.05};
export function decideAgencyRollup(input:{journeyCount:number;distinctUserCount:number;totalDurationSeconds:number;violationJourneyCount:number}):
  {status:'trusted'|'avoid'|'insufficient_evidence';confidence:number;reasons:string[]} {
  const {journeyCount,distinctUserCount,totalDurationSeconds,violationJourneyCount}=input;
  const evidenceRatio=Math.min(1,journeyCount/ROLLUP_THRESHOLDS.minimumJourneys,distinctUserCount/ROLLUP_THRESHOLDS.minimumDistinctUsers,totalDurationSeconds/ROLLUP_THRESHOLDS.minimumDurationSeconds);
  const reasons:string[]=[];
  if(journeyCount<ROLLUP_THRESHOLDS.minimumJourneys)reasons.push(`Needs ${ROLLUP_THRESHOLDS.minimumJourneys} journeys; has ${journeyCount}`);
  if(distinctUserCount<ROLLUP_THRESHOLDS.minimumDistinctUsers)reasons.push(`Needs ${ROLLUP_THRESHOLDS.minimumDistinctUsers} distinct users; has ${distinctUserCount}`);
  if(totalDurationSeconds<ROLLUP_THRESHOLDS.minimumDurationSeconds)reasons.push(`Needs ${ROLLUP_THRESHOLDS.minimumDurationSeconds} seconds of telemetry; has ${totalDurationSeconds}`);
  if(reasons.length)return {status:'insufficient_evidence',confidence:round(evidenceRatio,4),reasons};
  const rate=journeyCount?violationJourneyCount/journeyCount:0;
  if(violationJourneyCount>=ROLLUP_THRESHOLDS.avoidMinimumViolationJourneys&&rate>=ROLLUP_THRESHOLDS.avoidRate)
    return {status:'avoid',confidence:round(Math.min(1,.6+rate)),reasons:[`${violationJourneyCount} of ${journeyCount} journeys had sustained violations`,`Violation journey rate ${round(rate*100,1)}% meets the ${ROLLUP_THRESHOLDS.avoidRate*100}% avoid threshold`]};
  if(rate<=ROLLUP_THRESHOLDS.trustedMaximumViolationRate)
    return {status:'trusted',confidence:round(Math.min(1,.7+journeyCount/100)),reasons:[`Violation journey rate ${round(rate*100,1)}% is at or below ${ROLLUP_THRESHOLDS.trustedMaximumViolationRate*100}%`,`Minimum independent evidence thresholds met`]};
  return {status:'insufficient_evidence',confidence:round(.5+Math.min(.3,journeyCount/100)),reasons:[`Violation rate ${round(rate*100,1)}% is between trusted and avoid thresholds`]};
}

export function sanitizeSummaryFacts(input:Record<string,unknown>):Record<string,unknown> {
  const allowed=['period','periodStart','periodEnd','status','resultType','confidence','journeyCount','distinctUserCount','acceptedSampleCount','rejectedSampleCount','totalDurationSeconds','durationSeconds','violationJourneyCount','violationEpisodeCount','episodeCount','independentReporterCount','outlierCount','weightedSpeedKph','peakSpeedKph','averageSpeedKph','speedLimitKph','maxOverByKph','reasons','thresholds'];
  return Object.fromEntries(allowed.filter(key=>key in input).map(key=>[key,input[key]]));
}
