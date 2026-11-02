-- ============================================================
-- Two shared logins: staff may record, admin may also undo.
--
-- Hiding buttons in the page is convenience, not security — anyone can open
-- devtools. These policies are what actually stop a staff login from
-- rewriting figures that are already recorded. Run after restoring the
-- project, in SQL Editor → New query.
-- ============================================================

-- Pre-authorise both logins so they join with the right role the moment the
-- users are created in Authentication → Users.
insert into public.invites (email, role) values
  ('staff@projectdrex-sales.com', 'staff'),
  ('admin@projectdrex-sales.com', 'owner')
on conflict (email) do update set role = excluded.role;

-- If the users already exist, set their roles directly too.
insert into public.members (user_id, email, role)
select u.id, u.email, case when u.email like 'admin@%' then 'owner' else 'staff' end
from auth.users u
where u.email in ('staff@projectdrex-sales.com','admin@projectdrex-sales.com')
on conflict (user_id) do update set role = excluded.role;

-- ---------------------------------------------------------------- entries
drop policy if exists members_all    on public.entries;
drop policy if exists read_entries   on public.entries;
drop policy if exists insert_entries on public.entries;
drop policy if exists update_entries on public.entries;
drop policy if exists delete_entries on public.entries;

create policy read_entries on public.entries
  for select using (public.is_member());

-- Staff may write a live row. Only an owner may mark one deleted, which is
-- how "remove this day" and "delete this month" are stored.
create policy insert_entries on public.entries
  for insert with check (public.is_member() and (deleted = false or public.is_owner()));
create policy update_entries on public.entries
  for update using (public.is_member())
  with check (public.is_member() and (deleted = false or public.is_owner()));
create policy delete_entries on public.entries
  for delete using (public.is_owner());

-- ---------------------------------------------------------------- expenses
drop policy if exists members_all     on public.expenses;
drop policy if exists read_expenses   on public.expenses;
drop policy if exists insert_expenses on public.expenses;
drop policy if exists update_expenses on public.expenses;
drop policy if exists delete_expenses on public.expenses;

create policy read_expenses on public.expenses
  for select using (public.is_member());
create policy insert_expenses on public.expenses
  for insert with check (public.is_member() and (deleted = false or public.is_owner()));
create policy update_expenses on public.expenses
  for update using (public.is_member())
  with check (public.is_member() and (deleted = false or public.is_owner()));
create policy delete_expenses on public.expenses
  for delete using (public.is_owner());

-- ---------------------------------------------------------------- employees
-- The team list is report structure, not a daily input: staff read it only.
drop policy if exists members_all    on public.employees;
drop policy if exists read_employees on public.employees;
drop policy if exists write_employees on public.employees;

create policy read_employees on public.employees
  for select using (public.is_member());
create policy write_employees on public.employees
  for all using (public.is_owner()) with check (public.is_owner());
