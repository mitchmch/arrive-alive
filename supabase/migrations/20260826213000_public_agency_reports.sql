-- Sanitized, immutable public agency report snapshots. Only the service-role
-- Edge Function can read or write this table; public visitors use the API route.
create table public.public_agency_reports (
  id bigint generated always as identity primary key,
  slug text not null unique check (slug ~ '^[a-z0-9_-]{12,80}$'),
  agency_stable_id text not null,
  snapshot jsonb not null,
  created_by bigint references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  check (jsonb_typeof(snapshot) = 'object')
);

create index public_agency_reports_active_slug_idx
  on public.public_agency_reports(slug)
  where revoked_at is null;
create index public_agency_reports_agency_idx
  on public.public_agency_reports(agency_stable_id, created_at desc);

alter table public.public_agency_reports enable row level security;
revoke all on public.public_agency_reports from anon, authenticated;
revoke all on sequence public.public_agency_reports_id_seq from anon, authenticated;
