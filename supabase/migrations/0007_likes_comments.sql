-- Activity likes (unique per user+activity)
create table if not exists activity_likes (
  id          uuid primary key default gen_random_uuid(),
  activity_id uuid not null references activities(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique(activity_id, user_id)
);
create index if not exists activity_likes_activity_idx on activity_likes(activity_id);
create index if not exists activity_likes_user_idx    on activity_likes(user_id);

alter table activity_likes enable row level security;
create policy likes_select on activity_likes for select to authenticated using (true);
create policy likes_insert on activity_likes for insert to authenticated with check (user_id = auth.uid());
create policy likes_delete on activity_likes for delete to authenticated using (user_id = auth.uid());

-- Activity comments
create table if not exists activity_comments (
  id          uuid primary key default gen_random_uuid(),
  activity_id uuid not null references activities(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  content     text not null check (char_length(content) between 1 and 500),
  created_at  timestamptz not null default now()
);
create index if not exists activity_comments_activity_idx on activity_comments(activity_id);

alter table activity_comments enable row level security;
create policy comments_select on activity_comments for select to authenticated using (true);
create policy comments_insert on activity_comments for insert to authenticated with check (user_id = auth.uid());
create policy comments_delete on activity_comments for delete to authenticated using (user_id = auth.uid());

-- Single-call stats RPC: like_count, comment_count, is_liked for one activity
create or replace function activity_stats(p_activity_id uuid, p_user_id uuid)
returns table(like_count bigint, comment_count bigint, is_liked boolean)
language sql
security definer
set search_path = ''
as $$
  select
    (select count(*) from public.activity_likes    where activity_id = p_activity_id),
    (select count(*) from public.activity_comments where activity_id = p_activity_id),
    exists(select 1  from public.activity_likes    where activity_id = p_activity_id and user_id = p_user_id);
$$;
