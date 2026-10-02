-- 0014_mutual_connections.sql
-- Convert unidirectional follows → bidirectional connections with status.

-- 1. Add status column (existing rows default to 'accepted' for backward compat)
ALTER TABLE public.follows
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'accepted'
    CHECK (status IN ('pending', 'accepted'));

-- Change default for new inserts to 'pending' so new requests need acceptance
ALTER TABLE public.follows
    ALTER COLUMN status SET DEFAULT 'pending';

-- 2. Update follows RLS: sender and recipient see their own rows, either party can delete
DROP POLICY IF EXISTS follows_select ON follows;
DROP POLICY IF EXISTS follows_insert ON follows;
DROP POLICY IF EXISTS follows_delete ON follows;
DROP POLICY IF EXISTS follows_update ON follows;

CREATE POLICY follows_select ON follows
    FOR SELECT TO authenticated USING (
        follower_id = auth.uid() OR followee_id = auth.uid()
    );
CREATE POLICY follows_insert ON follows
    FOR INSERT TO authenticated WITH CHECK (follower_id = auth.uid());
CREATE POLICY follows_update ON follows
    FOR UPDATE TO authenticated
    USING (followee_id = auth.uid() AND status = 'pending')
    WITH CHECK (followee_id = auth.uid());
CREATE POLICY follows_delete ON follows
    FOR DELETE TO authenticated USING (
        follower_id = auth.uid() OR followee_id = auth.uid()
    );

-- 3. Update activities visibility check: accepted connections in either direction
DROP POLICY IF EXISTS activities_select ON activities;
CREATE POLICY activities_select ON activities
    FOR SELECT TO authenticated USING (
        user_id = auth.uid()
        OR auth_is_participant(id)
        OR visibility = 'public'
        OR (
            visibility IN ('followers', 'industry_followers')
            AND EXISTS (
                SELECT 1 FROM public.follows f
                WHERE ((f.follower_id = auth.uid() AND f.followee_id = activities.user_id)
                    OR (f.followee_id = auth.uid() AND f.follower_id = activities.user_id))
                  AND f.status = 'accepted'
            )
        )
    );

-- 4. Update social_feed: connections in either direction, accepted only
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

-- 5. SECURITY DEFINER helper: connection count (either direction, accepted only)
CREATE OR REPLACE FUNCTION connection_count(p_user_id UUID)
RETURNS TABLE(n BIGINT)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT COUNT(*) FROM public.follows
    WHERE (follower_id = p_user_id OR followee_id = p_user_id)
      AND status = 'accepted';
$$;
GRANT EXECUTE ON FUNCTION connection_count(UUID) TO authenticated;

-- 6. SECURITY DEFINER helper: list accepted connections for any user
CREATE OR REPLACE FUNCTION get_connections(p_user_id UUID)
RETURNS TABLE (
    id         UUID,
    real_name  TEXT,
    instrument TEXT,
    major      TEXT,
    avatar_url TEXT
)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT p.id, p.real_name, p.instrument, p.major, p.avatar_url
    FROM public.follows f
    JOIN public.profiles p ON (
        (f.follower_id = p_user_id AND p.id = f.followee_id)
        OR (f.followee_id = p_user_id AND p.id = f.follower_id)
    )
    WHERE (f.follower_id = p_user_id OR f.followee_id = p_user_id)
      AND f.status = 'accepted'
    ORDER BY p.real_name;
$$;
GRANT EXECUTE ON FUNCTION get_connections(UUID) TO authenticated;
