-- 0016_seed_accounts.sql
-- Seed/demo accounts: universal feed visibility + bulk-delete support.

-- 1. Mark seed accounts on profiles
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT false;

-- 2. Update social_feed to always surface seed-account activities to every user
CREATE OR REPLACE FUNCTION social_feed(p_user_id uuid)
RETURNS TABLE (
    id            uuid,
    user_id       uuid,
    type          text,
    title         text,
    activity_date text,
    location      text,
    role          text,
    program       text,
    prize         text,
    organizer     text,
    image_urls    text[],
    verification  text,
    author        jsonb,
    feed_reason   text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH
  my_connections AS (
    SELECT followee_id AS connection_id FROM follows
    WHERE follower_id = p_user_id AND status = 'accepted'
    UNION
    SELECT follower_id AS connection_id FROM follows
    WHERE followee_id = p_user_id AND status = 'accepted'
  ),
  own_ids AS (
    SELECT id FROM activities WHERE user_id = p_user_id
  ),
  following_ids AS (
    SELECT a.id
    FROM activities a
    JOIN my_connections c ON a.user_id = c.connection_id
    WHERE a.visibility::text != 'private'
  ),
  connection_commented_ids AS (
    SELECT DISTINCT a.id
    FROM activities a
    JOIN activity_comments ac ON ac.activity_id = a.id
    JOIN my_connections c      ON ac.user_id = c.connection_id
    WHERE a.id NOT IN (SELECT id FROM own_ids)
      AND a.id NOT IN (SELECT id FROM following_ids)
      AND a.user_id != p_user_id
      AND ac.user_id != p_user_id
      AND a.visibility::text IN ('public', 'industry_followers')
  ),
  -- Seed-account activities shown to every user regardless of connection
  seed_ids AS (
    SELECT a.id
    FROM activities a
    JOIN profiles p ON a.user_id = p.id
    WHERE p.is_seed = true
      AND a.visibility::text != 'private'
      AND a.id NOT IN (SELECT id FROM own_ids)
      AND a.id NOT IN (SELECT id FROM following_ids)
  ),
  feed AS (
    SELECT id, 'own'                  AS reason FROM own_ids
    UNION ALL
    SELECT id, 'following'            AS reason FROM following_ids
    UNION ALL
    SELECT id, 'connection_commented' AS reason FROM connection_commented_ids
    UNION ALL
    SELECT id, 'seed'                 AS reason FROM seed_ids
  )
  SELECT
    a.id,
    a.user_id,
    a.type::text,
    a.title,
    a.activity_date::text,
    a.location,
    a.role,
    a.program,
    a.prize,
    a.organizer,
    a.image_urls,
    a.verification::text,
    jsonb_build_object(
      'id',         p.id,
      'real_name',  p.real_name,
      'instrument', p.instrument
    ) AS author,
    f.reason AS feed_reason
  FROM feed f
  JOIN activities a ON a.id = f.id
  JOIN profiles p   ON a.user_id = p.id
  ORDER BY a.created_at DESC
  LIMIT 100;
$$;
