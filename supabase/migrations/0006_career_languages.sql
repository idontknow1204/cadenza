-- Career history (경력사항) and profile languages (언어)
-- Also adds graduation_year to affiliations

alter table public.affiliations
  add column if not exists graduation_year int;

-- Career / work history
create table public.careers (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  organization text not null,
  role         text not null,
  start_year   int,
  end_year     int,
  is_current   boolean not null default false,
  description  text,
  created_at   timestamptz not null default now()
);
create index careers_user_idx on public.careers(user_id);
alter table public.careers enable row level security;
create policy careers_select on public.careers for select to authenticated using (true);
create policy careers_insert on public.careers for insert to authenticated with check (user_id = auth.uid());
create policy careers_update on public.careers for update to authenticated using (user_id = auth.uid());
create policy careers_delete on public.careers for delete to authenticated using (user_id = auth.uid());

-- Languages
create table public.profile_languages (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null references public.profiles(id) on delete cascade,
  language  text not null,
  level     text not null check (level in ('native', 'fluent', 'intermediate', 'basic')),
  created_at timestamptz not null default now(),
  unique (user_id, language)
);
create index languages_user_idx on public.profile_languages(user_id);
alter table public.profile_languages enable row level security;
create policy languages_select on public.profile_languages for select to authenticated using (true);
create policy languages_insert on public.profile_languages for insert to authenticated with check (user_id = auth.uid());
create policy languages_update on public.profile_languages for update to authenticated using (user_id = auth.uid());
create policy languages_delete on public.profile_languages for delete to authenticated using (user_id = auth.uid());
