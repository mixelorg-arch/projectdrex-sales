-- Ledger — database schema
-- Run once in the Supabase SQL editor (Dashboard → SQL Editor → New query).

create table if not exists public.employees (
  id       text primary key,
  owner    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name     text not null,
  archived boolean not null default false
);

create table if not exists public.entries (
  id         text primary key,
  owner      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date       date not null,
  team_sales numeric not null default 0,
  pay        jsonb   not null default '{}'::jsonb,   -- {employeeId: amount}
  incentive  numeric not null default 0,
  paid       boolean not null default false,
  remarks    text    not null default ''
);

create table if not exists public.expenses (
  id     text primary key,
  owner  uuid not null default auth.uid() references auth.users(id) on delete cascade,
  month  text not null,                              -- 'YYYY-MM'
  name   text not null,
  amount numeric not null default 0,
  paid   boolean not null default false
);

create index if not exists entries_owner_date_idx on public.entries (owner, date);
create index if not exists expenses_owner_month_idx on public.expenses (owner, month);

-- Row level security: you can only ever see and change your own rows.
alter table public.employees enable row level security;
alter table public.entries   enable row level security;
alter table public.expenses  enable row level security;

do $$
declare t text;
begin
  foreach t in array array['employees','entries','expenses'] loop
    execute format('drop policy if exists own_rows on public.%I', t);
    execute format(
      'create policy own_rows on public.%I for all
         using (owner = auth.uid()) with check (owner = auth.uid())', t);
  end loop;
end $$;
