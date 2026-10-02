-- 0035: reliable opportunity ingestion pipeline
--
-- Adds source/run/item audit data, stable curated-row identities, safe publication
-- boundaries, and synchronization for denormalized location preferences.

CREATE TABLE opportunity_sources (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                 text NOT NULL UNIQUE,
  url                  text NOT NULL,
  language             text NOT NULL CHECK (language IN ('en', 'de', 'ko')),
  organization         text NOT NULL,
  city_id              text REFERENCES city(id),
  parser_key           text NOT NULL,
  enabled              boolean NOT NULL DEFAULT true,
  etag                 text,
  last_modified        text,
  content_hash         text,
  last_checked_at      timestamptz,
  last_success_at      timestamptz,
  consecutive_failures integer NOT NULL DEFAULT 0 CHECK (consecutive_failures >= 0),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE opportunity_sources ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON opportunity_sources FROM anon, authenticated;
GRANT ALL ON opportunity_sources TO service_role;

INSERT INTO opportunity_sources (slug, url, language, organization, city_id, parser_key)
VALUES
  ('munich-philharmonic',
   'https://www.mphil.de/ueber-uns/offene-stellen',
   'de', 'Münchner Philharmoniker', 'munich', 'munich_philharmonic'),
  ('oper-frankfurt',
   'https://oper-frankfurt.de/de/das-frankfurter-opern-und-museumsorchester/stellenangebote-des-orchesters/',
   'de', 'Oper Frankfurt', 'frankfurt', 'oper_frankfurt'),
  ('karajan-akademie',
   'https://www.berliner-philharmoniker.de/en/about-us/karajan-akademie/application-and-vacancies/',
   'en', 'Berliner Philharmoniker', 'berlin', 'karajan_akademie')
ON CONFLICT (slug) DO UPDATE SET
  url = EXCLUDED.url,
  language = EXCLUDED.language,
  organization = EXCLUDED.organization,
  city_id = EXCLUDED.city_id,
  parser_key = EXCLUDED.parser_key,
  updated_at = now();

CREATE TABLE opportunity_ingest_runs (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id      uuid NOT NULL REFERENCES opportunity_sources(id) ON DELETE CASCADE,
  started_at     timestamptz NOT NULL DEFAULT now(),
  finished_at    timestamptz,
  status         text NOT NULL DEFAULT 'running'
                 CHECK (status IN ('running', 'succeeded', 'skipped', 'failed')),
  http_status    integer,
  content_hash   text,
  found_count    integer NOT NULL DEFAULT 0,
  inserted_count integer NOT NULL DEFAULT 0,
  updated_count  integer NOT NULL DEFAULT 0,
  archived_count integer NOT NULL DEFAULT 0,
  warning_count  integer NOT NULL DEFAULT 0,
  parser_version text NOT NULL,
  error_message  text
);

CREATE INDEX opportunity_ingest_runs_source_started_idx
  ON opportunity_ingest_runs(source_id, started_at DESC);

ALTER TABLE opportunity_ingest_runs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON opportunity_ingest_runs FROM anon, authenticated;
GRANT ALL ON opportunity_ingest_runs TO service_role;

CREATE TABLE opportunity_raw_items (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_id    uuid NOT NULL REFERENCES opportunity_sources(id) ON DELETE CASCADE,
  run_id       uuid NOT NULL REFERENCES opportunity_ingest_runs(id) ON DELETE CASCADE,
  external_key text NOT NULL,
  source_url   text NOT NULL,
  content_hash text NOT NULL,
  payload      jsonb NOT NULL,
  fetched_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (run_id, external_key)
);

CREATE INDEX opportunity_raw_items_source_key_idx
  ON opportunity_raw_items(source_id, external_key, fetched_at DESC);

ALTER TABLE opportunity_raw_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON opportunity_raw_items FROM anon, authenticated;
GRANT ALL ON opportunity_raw_items TO service_role;
GRANT USAGE, SELECT ON SEQUENCE opportunity_raw_items_id_seq TO service_role;

ALTER TABLE jobs
  ADD COLUMN IF NOT EXISTS source_id uuid REFERENCES opportunity_sources(id),
  ADD COLUMN IF NOT EXISTS external_key text,
  ADD COLUMN IF NOT EXISTS source_content_hash text,
  ADD COLUMN IF NOT EXISTS first_seen_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS missing_runs integer NOT NULL DEFAULT 0
    CHECK (missing_runs >= 0),
  ADD COLUMN IF NOT EXISTS application_url text,
  ADD COLUMN IF NOT EXISTS fee_currency char(3),
  ADD COLUMN IF NOT EXISTS quality_score numeric(4,3)
    CHECK (quality_score IS NULL OR (quality_score >= 0 AND quality_score <= 1));

ALTER TABLE jobs ALTER COLUMN review_status SET DEFAULT 'needs_review';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'jobs_source_external_key_unique'
  ) THEN
    ALTER TABLE jobs ADD CONSTRAINT jobs_source_external_key_unique
      UNIQUE (source_id, external_key);
  END IF;
END
$$;

-- Attach rows imported by the original three adapters so the first pipeline run
-- updates them instead of duplicating them.
WITH candidates AS (
  SELECT
    j.id,
    s.id AS source_id,
    s.slug || ':' || md5(regexp_replace(lower(btrim(j.title)), '[^[:alnum:]]+', '', 'g')) AS external_key,
    row_number() OVER (
      PARTITION BY s.id, regexp_replace(lower(btrim(j.title)), '[^[:alnum:]]+', '', 'g')
      ORDER BY j.created_at DESC, j.id
    ) AS duplicate_rank
  FROM jobs j
  JOIN opportunity_sources s ON (
    j.source_url = s.url
    OR (s.slug = 'munich-philharmonic' AND j.organization = 'Münchner Philharmoniker')
    OR (s.slug = 'oper-frankfurt' AND j.organization = 'Oper Frankfurt')
    OR (s.slug = 'karajan-akademie' AND j.organization = 'Berliner Philharmoniker'
        AND j.title ILIKE 'Karajan-Akademie:%')
  )
  WHERE j.source = 'curated' AND j.source_id IS NULL
)
UPDATE jobs j
SET source_id = c.source_id,
    external_key = c.external_key,
    first_seen_at = coalesce(j.first_seen_at, j.created_at)
FROM candidates c
WHERE j.id = c.id AND c.duplicate_rank = 1;

CREATE INDEX jobs_published_deadline_idx
  ON jobs(deadline, id)
  WHERE is_active AND (source = 'user' OR review_status = 'published');
CREATE INDEX jobs_instruments_gin_idx ON jobs USING GIN (instruments);
CREATE INDEX jobs_organization_trgm_idx ON jobs USING GIN (organization gin_trgm_ops);
CREATE INDEX jobs_location_trgm_idx ON jobs USING GIN (location gin_trgm_ops);

-- Keep the denormalized zone correct for old and new rows.
CREATE OR REPLACE FUNCTION set_job_zone_from_city() RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.city_id IS NULL THEN
    NEW.zone := NULL;
  ELSE
    SELECT c.zone INTO NEW.zone FROM city c WHERE c.id = NEW.city_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS jobs_city_zone_trg ON jobs;
CREATE TRIGGER jobs_city_zone_trg
  BEFORE INSERT OR UPDATE OF city_id ON jobs
  FOR EACH ROW EXECUTE FUNCTION set_job_zone_from_city();

UPDATE jobs j SET zone = c.zone FROM city c WHERE j.city_id = c.id;

-- Keep Jobs' base-city preference aligned with profile edits, not only the
-- one-time migration backfill from 0027.
CREATE OR REPLACE FUNCTION sync_user_base_cities_from_profile() RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM user_base_city WHERE user_id = NEW.id;
  INSERT INTO user_base_city (user_id, city_id, is_primary)
  SELECT NEW.id, c.id, hc.ordinality = 1
  FROM unnest(coalesce(NEW.home_cities, '{}'::text[]))
       WITH ORDINALITY AS hc(slug, ordinality)
  JOIN city c ON c.id = hc.slug
  ON CONFLICT (user_id, city_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_home_cities_sync_trg ON profiles;
CREATE TRIGGER profiles_home_cities_sync_trg
  AFTER INSERT OR UPDATE OF home_cities ON profiles
  FOR EACH ROW EXECUTE FUNCTION sync_user_base_cities_from_profile();

-- Service-role-only reconciliation. A row is archived only after consecutive
-- successful runs omit it; failed or suspicious zero-item runs never call this.
CREATE OR REPLACE FUNCTION reconcile_opportunity_source(
  p_source_id uuid,
  p_seen_keys text[],
  p_close_after integer DEFAULT 3
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  archived integer := 0;
BEGIN
  IF p_close_after < 2 THEN
    RAISE EXCEPTION 'p_close_after must be at least 2';
  END IF;

  UPDATE jobs
  SET missing_runs = 0,
      last_seen_at = now()
  WHERE source_id = p_source_id
    AND external_key = ANY(coalesce(p_seen_keys, ARRAY[]::text[]));

  WITH changed AS (
    UPDATE jobs
    SET missing_runs = missing_runs + 1,
        status = CASE WHEN missing_runs + 1 >= p_close_after THEN 'closed' ELSE status END,
        is_active = CASE WHEN missing_runs + 1 >= p_close_after THEN false ELSE is_active END
    WHERE source_id = p_source_id
      AND is_active
      AND NOT (external_key = ANY(coalesce(p_seen_keys, ARRAY[]::text[])))
    RETURNING missing_runs
  )
  SELECT count(*) FILTER (WHERE missing_runs >= p_close_after) INTO archived FROM changed;

  RETURN archived;
END;
$$;

REVOKE ALL ON FUNCTION reconcile_opportunity_source(uuid, text[], integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION reconcile_opportunity_source(uuid, text[], integer)
  TO service_role;

-- Curated drafts and archived rows must not be readable through the app table.
DROP POLICY IF EXISTS "jobs_select" ON jobs;
CREATE POLICY "jobs_select" ON jobs
  FOR SELECT TO authenticated
  USING (source = 'user' OR review_status = 'published');

CREATE OR REPLACE FUNCTION search_opportunities(q text)
RETURNS SETOF jobs
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  qq text := left(lower(btrim(q)), 100);
  inst_ids text[];
BEGIN
  IF char_length(qq) < 2 THEN RETURN; END IF;

  SELECT array_agg(DISTINCT ia.instrument_id) INTO inst_ids
  FROM instrument_alias ia
  WHERE ia.alias = qq
     OR ia.alias ILIKE '%' || qq || '%'
     OR similarity(ia.alias, qq) > 0.3;

  RETURN QUERY
  SELECT j.*
  FROM jobs j
  LEFT JOIN city c ON c.id = j.city_id
  WHERE j.is_active
    AND (j.source = 'user' OR j.review_status = 'published')
    AND (
         j.search_vector @@ plainto_tsquery('simple', qq)
      OR j.title ILIKE '%' || qq || '%'
      OR j.organization ILIKE '%' || qq || '%'
      OR j.location ILIKE '%' || qq || '%'
      OR j.description ILIKE '%' || qq || '%'
      OR similarity(j.title, qq) > 0.3
      OR similarity(coalesce(j.organization, ''), qq) > 0.3
      OR c.name_ko ILIKE '%' || qq || '%'
      OR c.name_en ILIKE '%' || qq || '%'
      OR c.name_local ILIKE '%' || qq || '%'
      OR (inst_ids IS NOT NULL AND j.instruments && inst_ids)
    )
  ORDER BY
    ts_rank(coalesce(j.search_vector, ''::tsvector), plainto_tsquery('simple', qq)) DESC,
    j.deadline ASC NULLS LAST,
    j.created_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION search_opportunities(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION search_opportunities(text) TO authenticated;
