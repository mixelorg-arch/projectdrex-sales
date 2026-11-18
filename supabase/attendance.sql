-- ============================================================================
--  Ledger — let it read the attendance mirror as well.
--
--  The mirror tables themselves (salesinv_staff, salesinv_attendance) and the
--  function that fills them live in SalesInventory/supabase/attendance.sql.
--  They are in this same "ledger" Supabase project, so there is nothing to
--  copy — this file only widens who may read them.
--
--  Read only. Nothing here writes to entries, so no day and no figure anybody
--  has typed into the ledger is touched by any of it.
--
--  Run after SalesInventory/supabase/attendance.sql. Safe to re-run.
-- ============================================================================

-- A ledger member may read who was in. The till tablet may not: its login is a
-- member too, and browsing the team's attendance is not part of selling.
drop policy if exists salesinv_staff_ledger_read on public.salesinv_staff;
create policy salesinv_staff_ledger_read on public.salesinv_staff
  for select to authenticated
  using (public.is_member() and not public.is_till_staff());

drop policy if exists salesinv_attendance_ledger_read on public.salesinv_attendance;
create policy salesinv_attendance_ledger_read on public.salesinv_attendance
  for select to authenticated
  using (public.is_member() and not public.is_till_staff());

-- The refresh is the same one Sales & Inventory calls; it just was not open to
-- ledger members before. The body is unchanged — see the other file.
create or replace function public.salesinv_pull_attendance(p_days integer default 14)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, extensions, vault
as $$
declare
  v_from   date;
  v_to     date;
  v_url    text;
  v_key    text;
  v_token  text;
  v_resp   extensions.http_response;
  v_body   jsonb;
  n_staff  integer := 0;
  n_days   integer := 0;
begin
  if not (public.salesinv_is_owner()
          or (public.is_member() and not public.is_till_staff())) then
    raise exception 'not allowed to refresh attendance';
  end if;

  p_days := greatest(1, least(coalesce(p_days, 14), 92));
  -- The shop runs on Manila time; "today" must mean his today, not UTC's.
  v_to   := (now() at time zone 'Asia/Manila')::date;
  v_from := v_to - (p_days - 1);

  v_url   := public.salesinv_secret('ams_url');
  v_key   := public.salesinv_secret('ams_publishable_key');
  v_token := public.salesinv_secret('ams_feed_token');

  select * into v_resp from extensions.http((
    'POST',
    v_url || '/rest/v1/rpc/attendance_feed',
    array[
      extensions.http_header('apikey', v_key),
      extensions.http_header('Authorization', 'Bearer ' || v_key)
    ],
    'application/json',
    jsonb_build_object(
      'p_feed_id', 'salesinv',
      'p_token',   v_token,
      'p_from',    v_from,
      'p_to',      v_to
    )::text
  )::extensions.http_request);

  if v_resp.status <> 200 then
    -- Never echo the body: a failure from PostgREST can quote what was sent.
    raise exception 'attendance system refused the pull (HTTP %)', v_resp.status;
  end if;

  v_body := v_resp.content::jsonb;

  insert into public.salesinv_staff (code, full_name, position, active, synced_at)
  select s ->> 'code', s ->> 'full_name', s ->> 'position',
         coalesce((s ->> 'active')::boolean, true), now()
    from jsonb_array_elements(v_body -> 'staff') s
  on conflict (code) do update
    set full_name = excluded.full_name,
        position  = excluded.position,
        active    = excluded.active,
        synced_at = excluded.synced_at;
  get diagnostics n_staff = row_count;

  -- Clear and rewrite the window, so a punch deleted at the kiosk also goes.
  delete from public.salesinv_attendance where work_date between v_from and v_to;

  insert into public.salesinv_attendance (
    work_date, code, full_name, first_in, last_out,
    complete, punches, is_overtime, is_half_day, unverified, synced_at)
  select (d ->> 'work_date')::date,
         d ->> 'code',
         d ->> 'full_name',
         (d ->> 'first_in')::timestamptz,
         (d ->> 'last_out')::timestamptz,
         coalesce((d ->> 'complete')::boolean, true),
         coalesce((d ->> 'punches')::integer, 1),
         coalesce((d ->> 'is_overtime')::boolean, false),
         coalesce((d ->> 'is_half_day')::boolean, false),
         coalesce((d ->> 'unverified')::boolean, false),
         now()
    from jsonb_array_elements(v_body -> 'days') d;
  get diagnostics n_days = row_count;

  return jsonb_build_object(
    'ok', true, 'from', v_from, 'to', v_to,
    'staff', n_staff, 'days', n_days, 'as_of', v_body -> 'as_of');
end;
$$;

revoke all on function public.salesinv_pull_attendance(integer) from public, anon;
grant execute on function public.salesinv_pull_attendance(integer) to authenticated;
