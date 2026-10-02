-- 0029: Curated opportunity source metadata
--
-- Curated jobs should keep a trail back to the original public posting.
-- The importer can still write older databases without these columns, but
-- applying this migration gives reviewers enough context to audit rows before
-- they are shown broadly.

ALTER TABLE jobs
  ADD COLUMN IF NOT EXISTS source_url text,
  ADD COLUMN IF NOT EXISTS source_language text
    CHECK (source_language IS NULL OR source_language IN ('en', 'de', 'ko')),
  ADD COLUMN IF NOT EXISTS last_seen_at timestamptz,
  ADD COLUMN IF NOT EXISTS review_status text NOT NULL DEFAULT 'published'
    CHECK (review_status IN ('draft', 'needs_review', 'published', 'archived'));

CREATE INDEX IF NOT EXISTS jobs_source_url_idx ON jobs(source_url) WHERE source = 'curated';
CREATE INDEX IF NOT EXISTS jobs_review_status_idx ON jobs(review_status) WHERE source = 'curated';
