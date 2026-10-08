-- Simple tagging (no confirm workflow) + activity saves

-- ── activity_tags ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS activity_tags (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id    uuid        NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  tagged_user_id uuid        NOT NULL REFERENCES profiles(id)   ON DELETE CASCADE,
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (activity_id, tagged_user_id)
);

ALTER TABLE activity_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "view_tags"   ON activity_tags FOR SELECT TO authenticated USING (true);
CREATE POLICY "insert_tags" ON activity_tags FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM activities WHERE id = activity_id AND user_id = auth.uid()
  ));
CREATE POLICY "delete_tags" ON activity_tags FOR DELETE TO authenticated
  USING (auth.uid() = tagged_user_id
      OR EXISTS (SELECT 1 FROM activities WHERE id = activity_id AND user_id = auth.uid()));

-- ── activity_saves ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS activity_saves (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_id uuid        NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, activity_id)
);

ALTER TABLE activity_saves ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own_saves" ON activity_saves FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── activity_stats: add is_saved ──────────────────────────────────────────────

DROP FUNCTION IF EXISTS activity_stats(uuid, uuid);

CREATE FUNCTION activity_stats(p_activity_id uuid, p_user_id uuid)
RETURNS TABLE (
  like_count    bigint,
  comment_count bigint,
  is_liked      boolean,
  is_saved      boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    (SELECT COUNT(*) FROM activity_likes    WHERE activity_id = p_activity_id),
    (SELECT COUNT(*) FROM activity_comments WHERE activity_id = p_activity_id),
    EXISTS (SELECT 1 FROM activity_likes WHERE activity_id = p_activity_id AND user_id = p_user_id),
    EXISTS (SELECT 1 FROM activity_saves WHERE activity_id = p_activity_id AND user_id = p_user_id);
$$;
