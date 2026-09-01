-- Ledger — database schema
-- Run once in the Supabase SQL editor (Dashboard → SQL Editor → New query).
-- Safe to re-run.

-- Who is allowed into this ledger. One shared ledger, several people.
create table if not exists public.members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email   text,
  added_at timestamptz not null default now()
);

-- The first person to sign up becomes a member automatically. Everyone after
-- that has to be added deliberately (see the bottom of this file).
create or replace function public.claim_first_member()
returns trigger language plpgsql security definer as $$
begin
  if not exists (select 1 from public.members) then
    insert into public.members (user_id, email) values (new.id, new.email);
  end if;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.claim_first_member();

-- ---------------------------------------------------------------- data

create table if not exists public.employees (
  id         text primary key,
  name       text not null,
  archived   boolean not null default false,
  deleted    boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.entries (
  id         text primary key,
  date       date not null,
  team_sales numeric not null default 0,
  pay        jsonb   not null default '{}'::jsonb,   -- {employeeId: amount}
  incentive  numeric not null default 0,
  paid       boolean not null default false,
  remarks    text    not null default '',
  deleted    boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.expenses (
  id         text primary key,
  month      text not null,                          -- 'YYYY-MM'
  name       text not null,
  amount     numeric not null default 0,
  paid       boolean not null default false,
  deleted    boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists entries_date_idx      on public.entries (date);
create index if not exists entries_updated_idx   on public.entries (updated_at);
create index if not exists expenses_month_idx    on public.expenses (month);
create index if not exists expenses_updated_idx  on public.expenses (updated_at);
create index if not exists employees_updated_idx on public.employees (updated_at);

-- updated_at is set by the database, never trusted from the client — that is
-- what makes last-write-wins reliable across devices with wrong clocks.
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['employees','entries','expenses'] loop
    execute format('drop trigger if exists touch_%1$s on public.%1$I', t);
    execute format(
      'create trigger touch_%1$s before insert or update on public.%1$I
         for each row execute function public.touch_updated_at()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------- security

alter table public.members   enable row level security;
alter table public.employees enable row level security;
alter table public.entries   enable row level security;
alter table public.expenses  enable row level security;

create or replace function public.is_member()
returns boolean language sql stable security definer as $$
  select exists (select 1 from public.members where user_id = auth.uid());
$$;

drop policy if exists read_members on public.members;
create policy read_members on public.members
  for select using (user_id = auth.uid() or public.is_member());

do $$
declare t text;
begin
  foreach t in array array['employees','entries','expenses'] loop
    execute format('drop policy if exists members_all on public.%I', t);
    execute format(
      'create policy members_all on public.%I for all
         using (public.is_member()) with check (public.is_member())', t);
  end loop;
end $$;

-- ---------------------------------------------------------------- extras
--
-- To let someone else in, have them sign in once (which creates their auth
-- user but leaves them with no access), then run:
--
--   insert into public.members (user_id, email)
--   select id, email from auth.users where email = 'them@example.com';
--
-- To remove them:
--
--   delete from public.members m using auth.users u
--   where m.user_id = u.id and u.email = 'them@example.com';
-- ============================================================
-- Access control: owner/staff roles and an approval queue.
-- ============================================================

alter table public.members add column if not exists role text not null default 'staff';

-- Anyone who signs up lands here until an owner lets them in.
create table if not exists public.access_requests (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  email        text,
  requested_at timestamptz not null default now()
);
alter table public.access_requests enable row level security;

-- The first person to sign up owns the ledger. Everyone after waits.
create or replace function public.claim_first_member()
returns trigger language plpgsql security definer as $$
begin
  if not exists (select 1 from public.members) then
    insert into public.members (user_id, email, role) values (new.id, new.email, 'owner');
  else
    insert into public.access_requests (user_id, email) values (new.id, new.email)
      on conflict (user_id) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.claim_first_member();

create or replace function public.is_owner()
returns boolean language sql stable security definer as $$
  select exists (select 1 from public.members where user_id = auth.uid() and role = 'owner');
$$;

-- Members are readable by members; only an owner can grant or revoke access.
drop policy if exists read_members   on public.members;
drop policy if exists manage_members on public.members;
create policy read_members   on public.members for select using (user_id = auth.uid() or public.is_member());
create policy manage_members on public.members for all
  using (public.is_owner()) with check (public.is_owner());

-- You may see your own pending request; owners see and clear them all.
drop policy if exists own_request     on public.access_requests;
drop policy if exists owner_requests  on public.access_requests;
create policy own_request    on public.access_requests for select using (user_id = auth.uid());
create policy owner_requests on public.access_requests for all
  using (public.is_owner()) with check (public.is_owner());
