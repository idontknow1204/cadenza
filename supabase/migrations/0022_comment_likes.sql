-- 0020_comment_likes.sql
-- Likes on individual comments, and a helper function that returns
-- comments with per-user like counts in a single round-trip.

CREATE TABLE IF NOT EXISTS comment_likes (
  comment_id uuid        NOT NULL REFERENCES activity_comments(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES profiles(id)          ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (comment_id, user_id)
);

ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "comment_likes_owner"         ON comment_likes FOR ALL       USING (auth.uid() = user_id);
CREATE POLICY "comment_likes_public_read"   ON comment_likes FOR SELECT    TO authenticated USING (true);

-- Returns comments for an activity together with like_count and is_liked.
CREATE OR REPLACE FUNCTION get_comments(p_activity_id uuid, p_user_id uuid)
RETURNS TABLE (
  id                uuid,
  user_id           uuid,
  activity_id       uuid,
  content           text,
  created_at        timestamptz,
  parent_comment_id uuid,
  author            jsonb,
  like_count        bigint,
  is_liked          boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    ac.id,
    ac.user_id,
    ac.activity_id,
    ac.content,
    ac.created_at,
    ac.parent_comment_id,
    jsonb_build_object(
      'id',         pr.id,
      'real_name',  pr.real_name,
      'instrument', pr.instrument
    )                                                    AS author,
    COUNT(cl.user_id)::bigint                            AS like_count,
    COALESCE(BOOL_OR(cl.user_id = p_user_id), false)    AS is_liked
  FROM activity_comments ac
  JOIN profiles pr ON ac.user_id = pr.id
  LEFT JOIN comment_likes cl ON cl.comment_id = ac.id
  WHERE ac.activity_id = p_activity_id
  GROUP BY ac.id, pr.id
  ORDER BY ac.created_at ASC;
$$;
