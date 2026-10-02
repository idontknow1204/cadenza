-- Social feed RPC
-- Returns: own activities + following's (non-private) + public activities
-- that connected people (followees) have commented on.

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
  my_followees AS (
    SELECT followee_id
    FROM follows
    WHERE follower_id = p_user_id
  ),
  own_ids AS (
    SELECT id FROM activities WHERE user_id = p_user_id
  ),
  following_ids AS (
    SELECT a.id
    FROM activities a
    JOIN my_followees f ON a.user_id = f.followee_id
    WHERE a.visibility::text != 'private'
  ),
  -- Activities that my connections commented on, excluding ones already above
  connection_commented_ids AS (
    SELECT DISTINCT a.id
    FROM activities a
    JOIN activity_comments ac ON ac.activity_id = a.id
    JOIN my_followees f      ON ac.user_id = f.followee_id
    WHERE a.id NOT IN (SELECT id FROM own_ids)
      AND a.id NOT IN (SELECT id FROM following_ids)
      AND a.user_id != p_user_id
      AND ac.user_id != p_user_id
      AND a.visibility::text IN ('public', 'industry_followers')
  ),
  feed AS (
    SELECT id, 'own'                  AS reason FROM own_ids
    UNION ALL
    SELECT id, 'following'            AS reason FROM following_ids
    UNION ALL
    SELECT id, 'connection_commented' AS reason FROM connection_commented_ids
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
