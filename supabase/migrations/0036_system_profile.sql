-- 0036: keep service-owned content separate from member discovery

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_system boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS profiles_system_idx
  ON profiles(is_system) WHERE is_system;

COMMENT ON COLUMN profiles.is_system IS
  'True for non-human service owners such as the curated opportunity importer.';
