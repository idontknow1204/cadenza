-- 0052_get_comments_avatar.sql
-- get_comments RPC에 avatar_url 추가 — ProfileLite 디코딩에 필요
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
      'instrument', pr.instrument,
      'avatar_url', pr.avatar_url
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
