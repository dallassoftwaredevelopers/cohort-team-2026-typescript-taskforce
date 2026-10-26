-- Baseline for bills, properties and vendors. These tables were created on the
-- shared project outside migrations; this file matches their live definitions
-- (catalog metadata read 2026-10-26). The "if not exists" guards make it a
-- no-op wherever the tables and policies already exist.

-- users_id_seq privileges as on the live project. Without this, a fresh replay
-- depends on the local image's default privileges when the users migration runs.
grant select, update, usage on sequence public.users_id_seq to anon, authenticated, service_role;

create table if not exists public.bills (
  bill_id serial primary key,
  amount numeric(12,2) null,
  property varchar null,
  payment_method varchar null,
  created_at timestamp not null default current_timestamp
);

create table if not exists public.properties (
  property_id serial primary key,
  property_name varchar null,
  property_address varchar null,
  property_phone varchar null,
  created_at timestamp not null default current_timestamp
);

create table if not exists public.vendors (
  vendor_id serial primary key,
  vendor_name varchar null,
  vendor_address varchar null,
  vendor_contact_name varchar null,
  vendor_phone varchar null,
  payment_portal_url varchar null,
  supported_payment_method varchar null,
  created_at timestamp not null default current_timestamp,
  updated_at timestamp not null default current_timestamp
);

alter table public.bills enable row level security;
alter table public.properties enable row level security;
alter table public.vendors enable row level security;

-- Existing live policies, unchanged. Postgres has no "create policy if not exists",
-- so each one is created only when missing.
do $$
declare
  p record;
begin
  for p in
    select * from (values
      ('bills', 'bills table is public',
       'create policy "bills table is public" on public.bills for select to anon, authenticated using (true)'),
      ('bills', 'authenticated users can insert bills',
       'create policy "authenticated users can insert bills" on public.bills for insert to authenticated with check (true)'),
      ('bills', 'authenticated users update bills',
       'create policy "authenticated users update bills" on public.bills for update to authenticated using (true) with check (true)'),
      ('properties', 'properties table is public',
       'create policy "properties table is public" on public.properties for select to anon, authenticated using (true)'),
      ('properties', 'authenticated users can insert properties',
       'create policy "authenticated users can insert properties" on public.properties for insert to authenticated with check (true)'),
      ('properties', 'authenticated users update properties',
       'create policy "authenticated users update properties" on public.properties for update to authenticated using (true) with check (true)'),
      ('vendors', 'vendors table is public',
       'create policy "vendors table is public" on public.vendors for select to anon, authenticated using (true)'),
      ('vendors', 'authenticated users can insert vendors',
       'create policy "authenticated users can insert vendors" on public.vendors for insert to authenticated with check (true)'),
      ('vendors', 'authenticated users update vendors',
       'create policy "authenticated users update vendors" on public.vendors for update to authenticated using (true) with check (true)')
    ) as v(tbl, name, ddl)
  loop
    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = p.tbl and policyname = p.name
    ) then
      execute p.ddl;
    end if;
  end loop;
end
$$;
