-- PROPOSAL ONLY: do not run until reviewed and separately approved.
-- Does not alter public."Students".
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('primary_admin')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.site_settings (
  key text primary key,
  value text not null default '',
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
alter table public.site_settings enable row level security;
create or replace function public.is_active_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists(select 1 from public.admin_users au where au.user_id=(select auth.uid()) and au.active=true);
$$;
revoke all on function public.is_active_admin() from public;
grant execute on function public.is_active_admin() to authenticated;
create policy "admin_users_select_self" on public.admin_users
for select to authenticated using (user_id=(select auth.uid()) and active=true);
create policy "site_settings_admin_select" on public.site_settings
for select to authenticated using ((select public.is_active_admin()));
create policy "site_settings_admin_insert" on public.site_settings
for insert to authenticated with check ((select public.is_active_admin()));
create policy "site_settings_admin_update" on public.site_settings
for update to authenticated using ((select public.is_active_admin())) with check ((select public.is_active_admin()));
-- No client-side policy permits changing admin_users. Seed Director's UUID only via a
-- controlled privileged process after verifying the account and approving the exact operation.
