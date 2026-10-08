-- 0010: Threaded comments · tag acceptance · activity personal note

-- ── 1. Threaded replies on comments ──────────────────────────────────────────

ALTER TABLE activity_comments
  ADD COLUMN IF NOT EXISTS parent_comment_id uuid
    REFERENCES activity_comments(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS activity_comments_parent_idx
  ON activity_comments(parent_comment_id);

-- ── 2. Tag acceptance status ──────────────────────────────────────────────────
-- pending  → tagged user has not yet responded
-- accepted → tagged user accepted; activity appears on their profile
-- declined → rejected (row may be deleted instead)

ALTER TABLE activity_tags
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending';

-- Back-fill existing tags so they continue to appear (pre-pivot behaviour)
UPDATE activity_tags SET status = 'accepted' WHERE status = 'pending';

-- Tagged user may update their own tag status
CREATE POLICY "update_own_tag" ON activity_tags FOR UPDATE TO authenticated
  USING  (auth.uid() = tagged_user_id)
  WITH CHECK (auth.uid() = tagged_user_id);

-- ── 3. Personal story / impression on activities ───────────────────────────────

ALTER TABLE activities
  ADD COLUMN IF NOT EXISTS personal_note text;
