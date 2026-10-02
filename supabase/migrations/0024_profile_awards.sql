create table public.profile_awards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (length(btrim(title)) > 0),
  prize text not null check (length(btrim(prize)) > 0),
  issuer text not null default '',
  year integer not null check (year between 1900 and 9999),
  details text not null default '',
  link_url text not null default '' check (link_url = '' or link_url ~* '^https?://[^[:space:]]+$'),
  created_at timestamptz not null default now()
);

create index profile_awards_user_year_idx on public.profile_awards(user_id, year desc);
alter table public.profile_awards enable row level security;

-- Awards follow the same authenticated profile visibility as career history.
grant select, insert, update, delete on public.profile_awards to authenticated;
revoke all on public.profile_awards from anon;
create policy profile_awards_select on public.profile_awards
  for select to authenticated using (true);
create policy profile_awards_insert on public.profile_awards
  for insert to authenticated with check (user_id = auth.uid());
create policy profile_awards_update on public.profile_awards
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());
create policy profile_awards_delete on public.profile_awards
  for delete to authenticated using (user_id = auth.uid());
