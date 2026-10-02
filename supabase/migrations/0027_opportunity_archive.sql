-- 0027: Opportunity archive foundation (기회 아카이브 1단계 — 스키마 토대)
--
-- Evolves the existing `jobs` table into the discovery archive described in
-- 기회아카이브_수집계획_탐색설계 §6–9, without breaking existing user posts.
--   • city            — canonical city dictionary (PK = slug, matches
--                       OnboardingData.cityOptions ids already stored in
--                       profiles.home_cities, so no id mapping is needed)
--   • user_base_city  — a user's base cities (§6), backfilled from home_cities,
--                       with valid_from/to for temporary bases (임시 거점)
--   • jobs.*          — discovery columns (source, city, zone, event dates,
--                       video round, fee/scholarship, age, status, search)
--
-- Everything added to `jobs` is nullable or defaulted, so rows created by the
-- current user-post flow keep working unchanged.

-- Fuzzy search (오타 허용, §8)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ── city ────────────────────────────────────────────────────────────────
CREATE TABLE city (
  id            text PRIMARY KEY,          -- slug (e.g. 'berlin'), = cityOptions id
  name_en       text NOT NULL,
  name_local    text,                      -- native/local name (Köln, Wien …)
  name_ko       text,
  country_code  char(2) NOT NULL,
  lat           double precision,          -- nullable for now; radius sort is later
  lng           double precision,
  zone          text                       -- 'Z1' 'Z2' 'Z3' 'Z4' … (null = 미편입)
);

ALTER TABLE city ENABLE ROW LEVEL SECURITY;
CREATE POLICY "city_select" ON city FOR SELECT TO authenticated USING (true);

-- Seed from OnboardingData.cityOptions (single source of truth for cities).
-- Zone mapping per plan §1: Z1 Berlin · Z2 Germany · Z3 AT/CH · Z4 Korea.
INSERT INTO city (id, name_en, name_local, name_ko, country_code, zone) VALUES
  -- 🇰🇷 Korea (Z4)
  ('seoul',        'Seoul',        'Seoul',        '서울',       'KR', 'Z4'),
  ('busan',        'Busan',        'Busan',        '부산',       'KR', 'Z4'),
  ('daegu',        'Daegu',        'Daegu',        '대구',       'KR', 'Z4'),
  ('gwangju',      'Gwangju',      'Gwangju',      '광주',       'KR', 'Z4'),
  ('daejeon',      'Daejeon',      'Daejeon',      '대전',       'KR', 'Z4'),
  ('incheon',      'Incheon',      'Incheon',      '인천',       'KR', 'Z4'),
  -- 🇩🇪 Germany (Berlin = Z1, rest = Z2)
  ('berlin',       'Berlin',       'Berlin',       '베를린',     'DE', 'Z1'),
  ('munich',       'Munich',       'München',      '뮌헨',       'DE', 'Z2'),
  ('hamburg',      'Hamburg',      'Hamburg',      '함부르크',   'DE', 'Z2'),
  ('cologne',      'Cologne',      'Köln',         '쾰른',       'DE', 'Z2'),
  ('frankfurt',    'Frankfurt',    'Frankfurt',    '프랑크푸르트','DE', 'Z2'),
  ('hannover',     'Hanover',      'Hannover',     '하노버',     'DE', 'Z2'),
  ('leipzig',      'Leipzig',      'Leipzig',      '라이프치히', 'DE', 'Z2'),
  ('dresden',      'Dresden',      'Dresden',      '드레스덴',   'DE', 'Z2'),
  ('dusseldorf',   'Düsseldorf',   'Düsseldorf',   '뒤셀도르프', 'DE', 'Z2'),
  ('freiburg',     'Freiburg',     'Freiburg',     '프라이부르크','DE', 'Z2'),
  ('stuttgart',    'Stuttgart',    'Stuttgart',    '슈투트가르트','DE', 'Z2'),
  ('weimar',       'Weimar',       'Weimar',       '바이마르',   'DE', 'Z2'),
  ('detmold',      'Detmold',      'Detmold',      '데트몰트',   'DE', 'Z2'),
  ('saarbrucken',  'Saarbrücken',  'Saarbrücken',  '자르브뤼켄', 'DE', 'Z2'),
  -- 🇦🇹 Austria · 🇨🇭 Switzerland (Z3)
  ('vienna',       'Vienna',       'Wien',         '빈',         'AT', 'Z3'),
  ('salzburg',     'Salzburg',     'Salzburg',     '잘츠부르크', 'AT', 'Z3'),
  ('graz',         'Graz',         'Graz',         '그라츠',     'AT', 'Z3'),
  ('zurich',       'Zurich',       'Zürich',       '취리히',     'CH', 'Z3'),
  ('geneva',       'Geneva',       'Genf',         '제네바',     'CH', 'Z3'),
  ('bern',         'Berne',        'Bern',         '베른',       'CH', 'Z3'),
  -- 이후 구역 (zone 미편입 — 유저 데이터 보고 결정, §1)
  ('paris',        'Paris',        'Paris',        '파리',       'FR', NULL),
  ('london',       'London',       'London',       '런던',       'GB', NULL),
  ('amsterdam',    'Amsterdam',    'Amsterdam',    '암스테르담', 'NL', NULL),
  ('rome',         'Rome',         'Roma',         '로마',       'IT', NULL),
  ('milan',        'Milan',        'Milano',       '밀라노',     'IT', NULL),
  ('new_york',     'New York',     'New York',     '뉴욕',       'US', NULL),
  ('boston',       'Boston',       'Boston',       '보스턴',     'US', NULL),
  ('philadelphia', 'Philadelphia', 'Philadelphia', '필라델피아', 'US', NULL),
  ('cleveland',    'Cleveland',    'Cleveland',    '클리블랜드', 'US', NULL),
  ('los_angeles',  'Los Angeles',  'Los Angeles',  '로스앤젤레스','US', NULL);

-- ── user_base_city ──────────────────────────────────────────────────────
CREATE TABLE user_base_city (
  user_id     uuid    NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  city_id     text    NOT NULL REFERENCES city(id),
  is_primary  boolean NOT NULL DEFAULT false,
  valid_from  date,                         -- 임시 거점 (기간 한정)
  valid_to    date,
  PRIMARY KEY (user_id, city_id)
);

CREATE INDEX user_base_city_user_idx ON user_base_city(user_id);

ALTER TABLE user_base_city ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ubc_select" ON user_base_city FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "ubc_insert" ON user_base_city FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "ubc_update" ON user_base_city FOR UPDATE TO authenticated USING (user_id = auth.uid());
CREATE POLICY "ubc_delete" ON user_base_city FOR DELETE TO authenticated USING (user_id = auth.uid());

-- Backfill from the base cities already collected during onboarding step 3.
-- Only slugs that exist in `city` are carried over.
INSERT INTO user_base_city (user_id, city_id)
SELECT p.id, c.id
FROM profiles p
CROSS JOIN LATERAL unnest(p.home_cities) AS hc(slug)
JOIN city c ON c.id = hc.slug
ON CONFLICT DO NOTHING;

-- ── jobs → opportunity archive columns ──────────────────────────────────
ALTER TABLE jobs
  ADD COLUMN source          text NOT NULL DEFAULT 'user'
                             CHECK (source IN ('user', 'curated')),
  ADD COLUMN city_id         text REFERENCES city(id),
  ADD COLUMN zone            text,
  ADD COLUMN event_start     date,
  ADD COLUMN event_end       date,
  ADD COLUMN video_audition  boolean NOT NULL DEFAULT false,  -- 영상 예선 (§6/§7)
  ADD COLUMN application_fee numeric,                          -- null=미상, 0=무료
  ADD COLUMN has_scholarship boolean NOT NULL DEFAULT false,
  ADD COLUMN age_min         integer,
  ADD COLUMN age_max         integer,
  ADD COLUMN age_reference   date,
  ADD COLUMN status          text NOT NULL DEFAULT 'open'
                             CHECK (status IN ('open', 'announced', 'closed')),
  ADD COLUMN search_vector   tsvector;

-- Keep zone in sync with the city's zone whenever a curated row references one.
UPDATE jobs j SET zone = c.zone FROM city c WHERE j.city_id = c.id;

-- Full-text search vector (§8): weighted title > org > location/instruments.
CREATE OR REPLACE FUNCTION jobs_search_vector_update() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.search_vector :=
      setweight(to_tsvector('simple', coalesce(NEW.title, '')), 'A')
    || setweight(to_tsvector('simple', coalesce(NEW.organization, '')), 'B')
    || setweight(to_tsvector('simple', coalesce(NEW.location, '')), 'C')
    || setweight(to_tsvector('simple', coalesce(array_to_string(NEW.instruments, ' '), '')), 'C');
  RETURN NEW;
END;
$$;

CREATE TRIGGER jobs_search_vector_trg
  BEFORE INSERT OR UPDATE ON jobs
  FOR EACH ROW EXECUTE FUNCTION jobs_search_vector_update();

-- Backfill existing rows (fires the trigger via a no-op touch).
UPDATE jobs SET title = title;

CREATE INDEX jobs_search_idx     ON jobs USING GIN (search_vector);
CREATE INDEX jobs_title_trgm_idx ON jobs USING GIN (title gin_trgm_ops);
CREATE INDEX jobs_city_deadline_idx ON jobs (city_id, deadline) WHERE is_active;
CREATE INDEX jobs_zone_idx       ON jobs (zone);
