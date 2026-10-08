-- Include post creation time in the feed so clients can show "1 hour ago" style labels.

DROP FUNCTION IF EXISTS social_feed(uuid);

CREATE FUNCTION social_feed(p_user_id uuid)
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
    created_at    text,
    author        jsonb,
    org           jsonb,
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
  my_org_follows AS (
    SELECT org_id FROM org_follows WHERE user_id = p_user_id
  ),
  own_ids AS (
    SELECT id FROM activities WHERE user_id = p_user_id
  ),
  following_ids AS (
    SELECT a.id FROM activities a
    JOIN my_connections c ON a.user_id = c.connection_id
    WHERE a.visibility::text != 'private'
  ),
  connection_commented_ids AS (
    SELECT DISTINCT ON (a.id) a.id,
           'connection_commented|' || pr.real_name AS reason
    FROM activities a
    JOIN activity_comments ac ON ac.activity_id = a.id
    JOIN my_connections c      ON ac.user_id = c.connection_id
    JOIN profiles pr           ON ac.user_id = pr.id
    WHERE a.user_id != p_user_id
      AND ac.user_id != p_user_id
      AND a.visibility::text IN ('public', 'industry_followers')
    ORDER BY a.id, ac.created_at DESC
  ),
  seed_ids AS (
    SELECT a.id FROM activities a
    JOIN profiles p ON a.user_id = p.id
    WHERE p.is_seed = true
      AND a.visibility::text != 'private'
  ),
  org_ids AS (
    SELECT a.id FROM activities a
    JOIN my_org_follows f ON a.org_id = f.org_id
    WHERE a.visibility::text != 'private'
  ),
  all_ids AS (
    SELECT id, 'own'        AS reason, 1 AS priority FROM own_ids
    UNION ALL SELECT id, 'following',  2 FROM following_ids
    UNION ALL SELECT id, 'org',        3 FROM org_ids
    UNION ALL SELECT id, reason,       4 FROM connection_commented_ids
    UNION ALL SELECT id, 'seed',       5 FROM seed_ids
  ),
  feed AS (
    SELECT DISTINCT ON (id) id, reason
    FROM all_ids
    ORDER BY id, priority
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
    a.created_at::text,
    jsonb_build_object('id', p.id, 'real_name', p.real_name, 'instrument', p.instrument) AS author,
    CASE WHEN a.org_id IS NOT NULL THEN
      jsonb_build_object('id', o.id, 'name', o.name, 'logo_url', o.logo_url, 'category', o.category)
    ELSE NULL END AS org,
    f.reason AS feed_reason
  FROM feed f
  JOIN activities   a ON a.id = f.id
  JOIN profiles     p ON a.user_id = p.id
  LEFT JOIN organizations o ON a.org_id = o.id
  ORDER BY a.created_at DESC
  LIMIT 100;
$$;
