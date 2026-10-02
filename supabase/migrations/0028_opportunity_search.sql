-- 0028: Opportunity search (기회 아카이브 §8 — 검색)
--
-- Builds on the search_vector added in 0027. Adds:
--   • instrument_alias  — cross-language instrument names (Violin/Violine → 바이올린)
--                          so a query in any language finds the canonical id.
--   • institution_alias — reserved for curated institution aliases
--                          (베를린 필 / Berlin Phil / Berliner Philharmoniker). Empty
--                          for now; filled by the curation pipeline later.
--   • search_opportunities(q) — full-text + trigram fuzzy search across title,
--                          organization, location, description, city names and
--                          instruments (via alias), ranked by relevance then deadline.

-- ── instrument_alias ────────────────────────────────────────────────────
CREATE TABLE instrument_alias (
  alias         text NOT NULL,        -- lowercased search term
  instrument_id text NOT NULL,        -- canonical Korean id
  PRIMARY KEY (alias, instrument_id)
);

ALTER TABLE instrument_alias ENABLE ROW LEVEL SECURITY;
CREATE POLICY "instrument_alias_select" ON instrument_alias
  FOR SELECT TO authenticated USING (true);

-- Seed from OnboardingData instruments: id(=ko), en, de all map to the id.
INSERT INTO instrument_alias (alias, instrument_id)
SELECT lower(a), inst.id
FROM (VALUES
  ('바이올린','violin','violine'),
  ('비올라','viola','viola'),
  ('첼로','cello','violoncello'),
  ('콘트라베이스','double bass','kontrabass'),
  ('하프','harp','harfe'),
  ('기타','guitar','gitarre'),
  ('피아노','piano','klavier'),
  ('반주','accompaniment','korrepetition'),
  ('오르간','organ','orgel'),
  ('하프시코드','harpsichord','cembalo'),
  ('포르테피아노','fortepiano','hammerklavier'),
  ('클래식 기타','classical guitar','klassische gitarre'),
  ('류트','lute','laute'),
  ('만돌린','mandolin','mandoline'),
  ('리코더','recorder','blockflöte'),
  ('비올라 다 감바','viola da gamba','viola da gamba'),
  ('아코디언','accordion','akkordeon'),
  ('플루트','flute','flöte'),
  ('오보에','oboe','oboe'),
  ('클라리넷','clarinet','klarinette'),
  ('바순','bassoon','fagott'),
  ('색소폰','saxophone','saxophon'),
  ('호른','horn','horn'),
  ('트럼펫','trumpet','trompete'),
  ('트롬본','trombone','posaune'),
  ('유포니엄','euphonium','euphonium'),
  ('튜바','tuba','tuba'),
  ('타악기','percussion','schlagwerk'),
  ('팀파니','timpani','pauke'),
  ('마림바','marimba','marimba'),
  ('소프라노','soprano','sopran'),
  ('메조소프라노','mezzo-soprano','mezzosopran'),
  ('알토','alto','alt'),
  ('테너','tenor','tenor'),
  ('바리톤','baritone','bariton'),
  ('베이스바리톤','bass-baritone','bassbariton'),
  ('베이스','bass','bass'),
  ('오케스트라 지휘','orchestral conducting','orchesterdirigieren'),
  ('합창 지휘','choral conducting','chordirigieren'),
  ('작곡','composition','komposition'),
  ('전자음악','electronic music','elektronische musik'),
  ('음악이론','music theory','musiktheorie'),
  ('음악학','musicology','musikwissenschaft'),
  ('음악교육','music education','musikpädagogik')
) AS inst(id, en, de)
CROSS JOIN LATERAL (VALUES (inst.id), (inst.en), (inst.de)) AS x(a)
ON CONFLICT DO NOTHING;

CREATE INDEX instrument_alias_trgm_idx ON instrument_alias USING GIN (alias gin_trgm_ops);

-- ── institution_alias (future curated aliases) ──────────────────────────
CREATE TABLE institution_alias (
  alias          text NOT NULL,
  canonical_name text NOT NULL,
  PRIMARY KEY (alias, canonical_name)
);

ALTER TABLE institution_alias ENABLE ROW LEVEL SECURITY;
CREATE POLICY "institution_alias_select" ON institution_alias
  FOR SELECT TO authenticated USING (true);

CREATE INDEX institution_alias_trgm_idx ON institution_alias USING GIN (alias gin_trgm_ops);

-- ── search_opportunities(q) ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION search_opportunities(q text)
RETURNS SETOF jobs
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  qq       text := lower(btrim(q));
  inst_ids text[];
  inst_names text[];
BEGIN
  IF qq = '' THEN RETURN; END IF;

  -- Resolve the query to canonical instrument ids via aliases (any language).
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
    AND (
         j.search_vector @@ plainto_tsquery('simple', qq)
      OR j.title        ILIKE '%' || qq || '%'
      OR j.organization ILIKE '%' || qq || '%'
      OR j.location     ILIKE '%' || qq || '%'
      OR j.description  ILIKE '%' || qq || '%'
      OR similarity(j.title, qq) > 0.3
      OR similarity(coalesce(j.organization, ''), qq) > 0.3
      OR c.name_ko    ILIKE '%' || qq || '%'
      OR c.name_en    ILIKE '%' || qq || '%'
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

GRANT EXECUTE ON FUNCTION search_opportunities(text) TO authenticated;
