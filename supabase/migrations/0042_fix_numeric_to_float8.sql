-- 0042: Change numeric columns in jobs to float8 for correct PostgREST serialization
--
-- PostgreSQL `numeric` is serialized by PostgREST as a JSON *string* (e.g. "0.900")
-- to preserve arbitrary precision. The iOS app declares these fields as Double?,
-- which JSONDecoder cannot decode from a string — causing a DecodingError that the
-- catch block in JobsView.load() surfaces as "연결을 확인하고 다시 시도해 주세요."
--
-- `float8` (double precision) covers all values the app uses:
--   • quality_score ∈ [0.0, 1.0] — import pipeline score, three decimal places
--   • application_fee ≥ 0 — application fee in euros/dollars; null means unknown
-- Both types are now serialized as JSON numbers by PostgREST.

ALTER TABLE jobs
  ALTER COLUMN quality_score TYPE float8,
  ALTER COLUMN application_fee TYPE float8;

-- Re-assert the quality_score range check (the cast drops the original constraint).
ALTER TABLE jobs
  DROP CONSTRAINT IF EXISTS jobs_quality_score_check,
  ADD CONSTRAINT jobs_quality_score_check
    CHECK (quality_score IS NULL OR (quality_score >= 0 AND quality_score <= 1));
