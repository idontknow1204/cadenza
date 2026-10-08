-- Retire old demo/manual curated rows that have no official source adapter.
-- User-authored opportunities are unaffected.

UPDATE jobs
SET is_active = false,
    status = 'closed',
    review_status = 'archived'
WHERE source = 'curated'
  AND source_id IS NULL;
