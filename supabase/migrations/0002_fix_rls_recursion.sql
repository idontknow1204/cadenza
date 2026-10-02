-- Fix: activities ↔ activity_participants RLS circular reference
-- Root cause: activities policy checks activity_participants,
--             activity_participants policy checks activities → infinite loop.
-- Solution: security definer helper functions bypass the other table's RLS.

-- Helper: check if the current user is a participant in an activity
-- (queries activity_participants without triggering its RLS policy)
create or replace function auth_is_participant(p_activity_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.activity_participants
    where activity_id = p_activity_id
      and participant_id = auth.uid()
  );
$$;

-- Helper: check if the current user owns an activity
-- (queries activities without triggering its RLS policy)
create or replace function auth_owns_activity(p_activity_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.activities
    where id = p_activity_id
      and user_id = auth.uid()
  );
$$;

-- Replace the circular policies
drop policy if exists activities_select on activities;
drop policy if exists participants_select on activity_participants;

-- activities: uses auth_is_participant() (security definer) → no recursion
create policy activities_select on activities
  for select to authenticated using (
    user_id = auth.uid()
    or auth_is_participant(id)
    or visibility = 'public'
    or (
      visibility in ('followers', 'industry_followers')
      and exists (
        select 1 from public.follows f
        where f.follower_id = auth.uid()
          and f.followee_id = activities.user_id
      )
    )
  );

-- activity_participants: uses auth_owns_activity() (security definer) → no recursion
-- approved rows are visible evidence of collaboration — intentionally readable.
create policy participants_select on activity_participants
  for select to authenticated using (
    participant_id = auth.uid()
    or auth_owns_activity(activity_id)
    or confirm = 'approved'
  );
