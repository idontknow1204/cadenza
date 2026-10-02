-- 0019_profile_extras.sql
-- Optional profile sections, CV/website links, and received recommendations.

-- ── Profiles: add optional fields ─────────────────────────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS visible_sections text[]  NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS cv_url           text,
  ADD COLUMN IF NOT EXISTS website_url      text;

-- ── Recommendations ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS recommendations (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id        uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  recommender_name    text        NOT NULL,
  recommender_title   text,
  recommender_user_id uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  body                text        NOT NULL,
  is_visible          boolean     NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE recommendations ENABLE ROW LEVEL SECURITY;

-- Recipient owns all CRUD on their recommendations
CREATE POLICY "recs_owner_all" ON recommendations
  FOR ALL USING (auth.uid() = recipient_id);

-- Authenticated users can read visible recommendations
CREATE POLICY "recs_authenticated_read" ON recommendations
  FOR SELECT TO authenticated USING (is_visible = true);
