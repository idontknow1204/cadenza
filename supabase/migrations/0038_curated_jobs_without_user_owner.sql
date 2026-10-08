-- Curated opportunities are service-owned records, not member posts. Keep
-- member-created jobs tied to a real profile while allowing curated rows to
-- exist without a fabricated auth account.

ALTER TABLE jobs ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE jobs DROP CONSTRAINT IF EXISTS jobs_user_owner_required;
ALTER TABLE jobs ADD CONSTRAINT jobs_user_owner_required
  CHECK (source = 'curated' OR user_id IS NOT NULL);
