-- Make the Edge-Function-only data plane explicit to database tooling.
-- The service role used by app-api bypasses RLS; anon/authenticated roles are
-- intentionally denied direct table access.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'users', 'app_sessions', 'agencies', 'journeys', 'incidents',
    'incident_confirmations', 'violations', 'speed_limits',
    'idempotency_keys', 'sync_state', 'audit_log'
  ]
  loop
    execute format(
      'create policy %I on public.%I as restrictive for all to anon, authenticated using (false) with check (false)',
      table_name || '_edge_api_only',
      table_name
    );
  end loop;
end
$$;

create index if not exists journeys_agency_id_idx
  on public.journeys (agency_id);

create index if not exists violations_agency_id_idx
  on public.violations (agency_id);

create index if not exists violations_journey_id_idx
  on public.violations (journey_id);
