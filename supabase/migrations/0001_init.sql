-- Cadenza — walking-skeleton schema
-- Core loop: profile → activity → tag participant → confirm → feed
-- Enums are fixed now so institution_verified can be added later without migration pain.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type activity_type as enum ('performance', 'competition', 'education', 'recording');
create type verification_status as enum ('pending', 'peer_confirmed', 'institution_verified');
create type confirm_status as enum ('requested', 'approved', 'rejected');
create type visibility as enum ('public', 'industry_followers', 'followers', 'private');

-- ---------------------------------------------------------------------------
-- profiles  (1:1 with auth.users)
-- ---------------------------------------------------------------------------
create table profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  real_name      text not null check (char_length(real_name) >= 2),
  instrument     text,
  affiliation    text,
  home_city      text,
  bio            text check (bio is null or char_length(bio) <= 300),
  avatar_url     text,
  default_visibility visibility not null default 'industry_followers',
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- activities  (authored by one user; participants live in a separate table)
-- ---------------------------------------------------------------------------
create table activities (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references profiles (id) on delete cascade,
  type           activity_type not null,
  title          text not null check (char_length(title) >= 1),
  activity_date  date not null,
  location       text,
  role           text,
  verification   verification_status not null default 'pending',
  visibility     visibility not null default 'industry_followers',
  created_at     timestamptz not null default now()
);
create index activities_user_id_idx on activities (user_id);
create index activities_date_idx on activities (activity_date desc);

-- ---------------------------------------------------------------------------
-- activity_participants  (the "함께한 사람" edge — each side sees its own view)
-- ---------------------------------------------------------------------------
create table activity_participants (
  id             uuid primary key default gen_random_uuid(),
  activity_id    uuid not null references activities (id) on delete cascade,
  participant_id uuid not null references profiles (id) on delete cascade,
  role           text,
  confirm        confirm_status not null default 'requested',
  created_at     timestamptz not null default now(),
  unique (activity_id, participant_id)
);
create index activity_participants_participant_idx on activity_participants (participant_id);
create index activity_participants_activity_idx on activity_participants (activity_id);

-- ---------------------------------------------------------------------------
-- follows  (single-direction — distinct from Confirm)
-- ---------------------------------------------------------------------------
create table follows (
  follower_id    uuid not null references profiles (id) on delete cascade,
  followee_id    uuid not null references profiles (id) on delete cascade,
  created_at     timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

-- ---------------------------------------------------------------------------
-- Auto-create a profile row when a user signs up
-- real_name is passed in auth metadata at sign-up time.
-- ---------------------------------------------------------------------------
create function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, real_name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'real_name', ''), '음악인')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ---------------------------------------------------------------------------
-- When a tagged participant approves, promote the activity to peer_confirmed.
-- This is the visible payoff of the core loop.
-- ---------------------------------------------------------------------------
create function promote_activity_on_confirm()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  if new.confirm = 'approved' and old.confirm is distinct from 'approved' then
    update public.activities
       set verification = 'peer_confirmed'
     where id = new.activity_id
       and verification = 'pending';
  end if;
  return new;
end;
$$;

create trigger on_participant_confirmed
  after update on activity_participants
  for each row execute function promote_activity_on_confirm();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- Principle: an activity a user is tagged in must NOT surface on their side
-- until confirm = 'approved'. Unconfirmed tags are visible only to the tagged
-- participant (their inbox) and the activity owner.
-- ---------------------------------------------------------------------------
alter table profiles enable row level security;
alter table activities enable row level security;
alter table activity_participants enable row level security;
alter table follows enable row level security;

-- profiles: readable by any authenticated user (needed for tagging/search);
-- writable only by the owner.
create policy profiles_select on profiles
  for select to authenticated using (true);
create policy profiles_insert on profiles
  for insert to authenticated with check (id = auth.uid());
create policy profiles_update on profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- activities: visible if I own it, I'm tagged in it, it's public, or I follow
-- the author and its visibility allows followers.
create policy activities_select on activities
  for select to authenticated using (
    user_id = auth.uid()
    or exists (
      select 1 from activity_participants ap
      where ap.activity_id = activities.id and ap.participant_id = auth.uid()
    )
    or visibility = 'public'
    or (
      visibility in ('followers', 'industry_followers')
      and exists (
        select 1 from follows f
        where f.follower_id = auth.uid() and f.followee_id = activities.user_id
      )
    )
  );
create policy activities_insert on activities
  for insert to authenticated with check (user_id = auth.uid());
create policy activities_update on activities
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy activities_delete on activities
  for delete to authenticated using (user_id = auth.uid());

-- activity_participants: the tagged user sees their own rows (inbox); the
-- activity owner sees rows on their activity; approved rows are visible to
-- anyone who can see the parent activity.
create policy participants_select on activity_participants
  for select to authenticated using (
    participant_id = auth.uid()
    or exists (
      select 1 from activities a
      where a.id = activity_participants.activity_id and a.user_id = auth.uid()
    )
    or (
      confirm = 'approved'
      and exists (select 1 from activities a where a.id = activity_participants.activity_id)
    )
  );
-- only the activity owner may tag participants.
create policy participants_insert on activity_participants
  for insert to authenticated with check (
    exists (
      select 1 from activities a
      where a.id = activity_id and a.user_id = auth.uid()
    )
  );
-- only the tagged participant may respond (approve / reject).
create policy participants_update on activity_participants
  for update to authenticated
  using (participant_id = auth.uid())
  with check (participant_id = auth.uid());

-- follows: readable by all authenticated; you manage only your own edges.
create policy follows_select on follows
  for select to authenticated using (true);
create policy follows_insert on follows
  for insert to authenticated with check (follower_id = auth.uid());
create policy follows_delete on follows
  for delete to authenticated using (follower_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Realtime — live updates for the confirm inbox and feed
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table activities;
alter publication supabase_realtime add table activity_participants;
