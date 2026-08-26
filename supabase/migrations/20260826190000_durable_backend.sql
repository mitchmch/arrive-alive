-- Arrive Alive durable backend. The app-api Edge Function is the only intended
-- data-plane and uses the service role; RLS denies direct anon/authenticated access.
create extension if not exists pgcrypto;

create type public.app_role as enum ('user', 'admin');
create type public.journey_status as enum ('active', 'completed', 'cancelled');
create type public.incident_status as enum ('active', 'resolved', 'removed');
create type public.violation_status as enum ('pending', 'validated', 'dismissed');

create table public.users (
  id bigint generated always as identity primary key,
  stable_id uuid not null default gen_random_uuid() unique,
  phone text not null unique check (length(phone) between 3 and 32),
  display_name text not null default '' check (length(display_name) <= 80),
  birth_year smallint check (birth_year between 1900 and 2100),
  role public.app_role not null default 'user',
  pin_hash text not null,
  pin_salt text not null,
  secret_hash text not null,
  secret_salt text not null,
  hash_iterations integer not null default 210000 check (hash_iterations >= 100000),
  photo_path text,
  disabled_at timestamptz,
  last_login_at timestamptz,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.app_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id bigint not null references public.users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  user_agent text,
  ip_hash text,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

create table public.agencies (
  id bigint generated always as identity primary key,
  stable_id text not null unique,
  name text not null,
  type text,
  region text,
  contact text,
  safety_score integer not null default 0 check (safety_score between 0 and 100),
  verified boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  version bigint not null default 1,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.journeys (
  id bigint generated always as identity primary key,
  stable_id text not null unique,
  user_id bigint not null references public.users(id) on delete cascade,
  agency_id bigint references public.agencies(id) on delete set null,
  mode text not null default 'car',
  vehicle_details jsonb not null default '{}'::jsonb,
  assets jsonb not null default '[]'::jsonb,
  defects jsonb not null default '[]'::jsonb,
  driver_name text,
  passenger_count integer not null default 1 check (passenger_count >= 0),
  start_lat double precision check (start_lat between -90 and 90),
  start_lng double precision check (start_lng between -180 and 180),
  end_lat double precision check (end_lat between -90 and 90),
  end_lng double precision check (end_lng between -180 and 180),
  start_time timestamptz not null default now(),
  end_time timestamptz,
  status public.journey_status not null default 'active',
  max_speed double precision not null default 0 check (max_speed >= 0),
  avg_speed double precision not null default 0 check (avg_speed >= 0),
  distance double precision not null default 0 check (distance >= 0),
  violation_count integer not null default 0 check (violation_count >= 0),
  score integer not null default 100 check (score between 0 and 100),
  path jsonb not null default '[]'::jsonb,
  client_updated_at timestamptz,
  version bigint not null default 1,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.incidents (
  id bigint generated always as identity primary key,
  stable_id text not null unique,
  reporter_user_id bigint references public.users(id) on delete set null,
  type text not null,
  description text,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  vehicle_reg text,
  driver_name text,
  status public.incident_status not null default 'active',
  confirmation_count integer not null default 0,
  not_there_count integer not null default 0,
  last_confirmed_at timestamptz,
  resolved_at timestamptz,
  client_updated_at timestamptz,
  version bigint not null default 1,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.incident_confirmations (
  id bigint generated always as identity primary key,
  incident_id bigint not null references public.incidents(id) on delete cascade,
  user_id bigint not null references public.users(id) on delete cascade,
  still_there boolean not null,
  idempotency_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (incident_id, user_id),
  unique (user_id, idempotency_key)
);

create table public.violations (
  id bigint generated always as identity primary key,
  stable_id text not null unique,
  journey_id bigint not null references public.journeys(id) on delete cascade,
  user_id bigint not null references public.users(id) on delete cascade,
  agency_id bigint references public.agencies(id) on delete set null,
  type text not null,
  speed double precision not null default 0 check (speed >= 0),
  speed_limit double precision not null default 0 check (speed_limit >= 0),
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  occurred_at timestamptz not null default now(),
  status public.violation_status not null default 'pending',
  published boolean not null default false,
  vehicle_reg text,
  route text,
  metadata jsonb not null default '{}'::jsonb,
  client_updated_at timestamptz,
  version bigint not null default 1,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.speed_limits (
  id bigint generated always as identity primary key,
  stable_id text not null unique,
  mode text not null unique,
  limit_kph integer not null check (limit_kph between 1 and 300),
  description text,
  version bigint not null default 1,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.idempotency_keys (
  user_id bigint not null references public.users(id) on delete cascade,
  key text not null,
  method text not null,
  path text not null,
  request_hash text not null,
  response_status integer,
  response_body jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  primary key (user_id, key)
);

create table public.sync_state (
  user_id bigint primary key references public.users(id) on delete cascade,
  revision bigint not null default 0,
  last_pull_at timestamptz,
  last_push_at timestamptz,
  last_error text,
  updated_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_user_id bigint references public.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  request_id text,
  ip_hash text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index app_sessions_active_idx on public.app_sessions(token_hash, expires_at) where revoked_at is null;
create index app_sessions_user_idx on public.app_sessions(user_id, created_at desc);
create index journeys_user_updated_idx on public.journeys(user_id, updated_at desc) where deleted_at is null;
create index journeys_status_idx on public.journeys(status, start_time desc) where deleted_at is null;
create index incidents_active_geo_idx on public.incidents(status, updated_at desc) where deleted_at is null;
create index incidents_reporter_idx on public.incidents(reporter_user_id, created_at desc);
create index confirmations_incident_idx on public.incident_confirmations(incident_id, updated_at desc);
create index violations_user_idx on public.violations(user_id, occurred_at desc) where deleted_at is null;
create index violations_review_idx on public.violations(status, occurred_at desc) where deleted_at is null;
create index audit_actor_created_idx on public.audit_log(actor_user_id, created_at desc);
create index audit_entity_idx on public.audit_log(entity_type, entity_id, created_at desc);
create index idempotency_expiry_idx on public.idempotency_keys(expires_at);

create or replace function public.set_row_updated_at() returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  if to_jsonb(new) ? 'version' then new.version = greatest(coalesce(old.version, 0) + 1, coalesce(new.version, 1)); end if;
  return new;
end $$;

create or replace function public.confirm_incident(p_incident_id bigint, p_user_id bigint, p_still_there boolean, p_idempotency_key text default null)
returns public.incidents language plpgsql security definer set search_path = public as $$
declare result public.incidents;
begin
  insert into public.incident_confirmations(incident_id, user_id, still_there, idempotency_key)
  values (p_incident_id, p_user_id, p_still_there, p_idempotency_key)
  on conflict (incident_id, user_id) do update set still_there = excluded.still_there, updated_at = now();
  update public.incidents set
    confirmation_count = (select count(*) from public.incident_confirmations where incident_id=p_incident_id and still_there),
    not_there_count = (select count(*) from public.incident_confirmations where incident_id=p_incident_id and not still_there),
    status = case when p_still_there then 'active'::public.incident_status else 'resolved'::public.incident_status end,
    last_confirmed_at = case when p_still_there then now() else last_confirmed_at end,
    resolved_at = case when p_still_there then null else now() end
  where id = p_incident_id returning * into result;
  if result.id is null then raise exception 'incident not found'; end if;
  return result;
end $$;
revoke all on function public.confirm_incident(bigint,bigint,boolean,text) from public, anon, authenticated;

create trigger users_updated before update on public.users for each row execute function public.set_row_updated_at();
create trigger agencies_updated before update on public.agencies for each row execute function public.set_row_updated_at();
create trigger journeys_updated before update on public.journeys for each row execute function public.set_row_updated_at();
create trigger incidents_updated before update on public.incidents for each row execute function public.set_row_updated_at();
create trigger violations_updated before update on public.violations for each row execute function public.set_row_updated_at();
create trigger speed_limits_updated before update on public.speed_limits for each row execute function public.set_row_updated_at();

alter table public.users enable row level security;
alter table public.app_sessions enable row level security;
alter table public.agencies enable row level security;
alter table public.journeys enable row level security;
alter table public.incidents enable row level security;
alter table public.incident_confirmations enable row level security;
alter table public.violations enable row level security;
alter table public.speed_limits enable row level security;
alter table public.idempotency_keys enable row level security;
alter table public.sync_state enable row level security;
alter table public.audit_log enable row level security;
-- No permissive policies: anon/authenticated have zero table access. service_role bypasses RLS.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

insert into public.speed_limits(stable_id, mode, limit_kph, description) values
 ('speed-car','car',60,'Default car limit'), ('speed-bus','bus',50,'Default bus limit'),
 ('speed-lorry','lorry',50,'Default lorry limit'), ('speed-motorbike','motorbike',60,'Default motorbike limit')
on conflict (mode) do nothing;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos','profile-photos',false,2097152,array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
-- Supabase Storage already enforces RLS on storage.objects. No client policy is
-- added; the Edge Function service role performs all object operations.
