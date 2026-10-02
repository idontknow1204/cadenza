-- Onboarding schema expansion
-- Replaces flat text affiliation/home_city with structured tables.

-- course_type enum
create type course_type as enum (
  'bachelor', 'master', 'phd', 'performance', 'diploma', 'other'
);

-- Expand profiles
alter table profiles
  add column if not exists major           text,
  add column if not exists home_cities     text[] not null default '{}',
  add column if not exists onboarding_complete boolean not null default false;

-- Remove old flat columns (no live data yet)
alter table profiles
  drop column if exists affiliation,
  drop column if exists home_city;

-- School/university affiliations (one user may have multiple over time)
create table affiliations (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references profiles(id) on delete cascade,
  institution_name text not null,
  course_type      course_type,
  enrollment_year  int  check (enrollment_year between 1950 and 2035),
  is_current       boolean not null default true,
  created_at       timestamptz not null default now()
);
create index affiliations_user_idx on affiliations(user_id);

-- Teacher-student lineage
create table lineage (
  id             uuid primary key default gen_random_uuid(),
  teacher_id     uuid references profiles(id) on delete set null,
  student_id     uuid not null references profiles(id) on delete cascade,
  teacher_name   text,          -- stored when teacher is not yet a user
  confirm_status text not null default 'pending'
                 check (confirm_status in ('pending', 'confirmed')),
  created_at     timestamptz not null default now(),
  unique (teacher_id, student_id)
);

-- RLS
alter table affiliations enable row level security;
alter table lineage enable row level security;

create policy affiliations_select on affiliations for select to authenticated using (true);
create policy affiliations_insert on affiliations for insert to authenticated with check (user_id = auth.uid());
create policy affiliations_update on affiliations for update to authenticated using (user_id = auth.uid());
create policy affiliations_delete on affiliations for delete to authenticated using (user_id = auth.uid());

create policy lineage_select on lineage for select to authenticated using (true);
create policy lineage_insert on lineage for insert to authenticated with check (student_id = auth.uid());
create policy lineage_update on lineage for update to authenticated
  using (student_id = auth.uid() or teacher_id = auth.uid());

-- Avatar storage bucket (public read, authenticated upload to own folder)
insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
  on conflict do nothing;

create policy "avatars_read" on storage.objects
  for select using (bucket_id = 'avatars');

create policy "avatars_upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text);
