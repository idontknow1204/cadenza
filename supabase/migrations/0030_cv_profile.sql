-- 0030: Fermata CV — person 필드 + canonical JSON 어셈블리
-- render-service 의 cv_data.schema.json 계약을 Postgres 에서 조립한다 (단일 진실원천).
--   • profiles 에 CV 인물 필드 추가 (slug/birth_year/phone/address/eyebrow/cv_version)
--   • public.cv_data(profile, public) -> jsonb : 스키마와 1:1로 대응하는 canonical JSON
--   • cv_version bump 트리거 : activities/affiliations/lineage 변경 시 캐시 무효화 신호

-- ---------------------------------------------------------------------------
-- 1. profiles CV 필드
-- ---------------------------------------------------------------------------
alter table profiles
  add column if not exists slug        text,
  add column if not exists birth_year  int  check (birth_year is null or birth_year between 1900 and 2035),
  add column if not exists phone       text,
  add column if not exists address     text,
  add column if not exists eyebrow     text,   -- 이름 위 마이크로 라벨 (예: 'VIOLINIST · BERLIN')
  add column if not exists cv_version  int not null default 0;

-- slug: 공개 프로필 주소(fermata.app/p/{slug}) 의 키
create or replace function public.slugify(txt text)
returns text language sql immutable as $$
  select trim(both '-' from regexp_replace(lower(coalesce(txt,'')), '[^a-z0-9]+', '-', 'g'));
$$;

-- id 기반 안정 토큰 — 라틴이 아닌 이름/충돌 폴백. md5 라 순차 seed id 에도 충돌 없음
create or replace function public.slug_token(id uuid, len int default 8)
returns text language sql immutable as $$
  select substr(md5(id::text), 1, len);
$$;

-- 없으면 생성: real_name 라틴화 → 비면 'u-<id토큰>', 충돌 시 접미사
create or replace function public.ensure_profile_slug()
returns trigger language plpgsql as $$
declare base text; cand text; n int := 0;
begin
  if new.slug is not null and btrim(new.slug) <> '' then
    return new;
  end if;
  base := nullif(public.slugify(new.real_name), '');
  -- 한글 등 라틴이 없는 이름은 slugify 결과가 비므로 id 기반으로
  if base is null then
    new.slug := 'u-' || public.slug_token(new.id, 10);
    return new;
  end if;
  cand := base;
  while exists (select 1 from profiles where slug = cand and id <> new.id) loop
    n := n + 1;
    cand := base || '-' || public.slug_token(new.id, 4 + n);
  end loop;
  new.slug := cand;
  return new;
end $$;

drop trigger if exists trg_profile_slug on profiles;
create trigger trg_profile_slug
  before insert or update of real_name, slug on profiles
  for each row execute function public.ensure_profile_slug();

-- 기존 행 backfill (라틴 없는 이름 → id 토큰, 라틴 충돌 → id 접미사)
update profiles p set slug = sub.cand
from (
  select id,
         case
           when base is null then 'u-' || public.slug_token(id, 10)
           when rn = 1       then base
           else base || '-' || public.slug_token(id, 6)
         end as cand
  from (
    select id,
           nullif(public.slugify(real_name), '') as base,
           row_number() over (
             partition by nullif(public.slugify(real_name), '')
             order by created_at
           ) as rn
    from profiles
  ) t
) sub
where p.id = sub.id and (p.slug is null or btrim(p.slug) = '');

create unique index if not exists profiles_slug_key on profiles (slug);

-- ---------------------------------------------------------------------------
-- 2. cv_version bump — activities/affiliations/lineage 변경 → 소유자 캐시 무효화
-- ---------------------------------------------------------------------------
create or replace function public.bump_cv_version()
returns trigger language plpgsql as $$
declare owner uuid;
begin
  -- IF 분기로 분리: 한 표현식에 new.student_id 와 new.user_id 를 함께 두면
  -- PL/pgSQL 이 안 타는 분기의 필드까지 해석해 다른 테이블 레코드에서 실패한다.
  if tg_table_name = 'lineage' then
    owner := coalesce(new.student_id, old.student_id);
  else
    owner := coalesce(new.user_id, old.user_id);
  end if;
  if owner is not null then
    update profiles set cv_version = cv_version + 1 where id = owner;
  end if;
  return coalesce(new, old);
end $$;

drop trigger if exists trg_cv_bump_act on activities;
create trigger trg_cv_bump_act after insert or update or delete on activities
  for each row execute function public.bump_cv_version();
drop trigger if exists trg_cv_bump_aff on affiliations;
create trigger trg_cv_bump_aff after insert or update or delete on affiliations
  for each row execute function public.bump_cv_version();
drop trigger if exists trg_cv_bump_lin on lineage;
create trigger trg_cv_bump_lin after insert or update or delete on lineage
  for each row execute function public.bump_cv_version();

-- ---------------------------------------------------------------------------
-- 3. 헬퍼: verification enum -> 스키마 문자열, course_type -> 학위 라벨
-- ---------------------------------------------------------------------------
create or replace function public.cv_verify(v verification_status)
returns text language sql immutable as $$
  select case v
           when 'institution_verified' then 'institution'
           when 'peer_confirmed'       then 'peer'
           else null
         end;
$$;

create or replace function public.cv_degree(ct course_type, instrument text)
returns text language sql immutable as $$
  select case ct
           when 'bachelor'   then 'Bachelor of Music'
           when 'master'     then 'Master of Music'
           when 'phd'        then 'Doctor of Music'
           when 'performance' then 'Performance Diploma'
           when 'diploma'    then 'Diploma'
           when 'highschool' then 'Music High School'
           else null
         end
       || case when instrument is not null and instrument <> '' then ', ' || instrument else '' end;
$$;

-- ---------------------------------------------------------------------------
-- 4. cv_data(profile, public) -> canonical JSON (render-service 계약)
--    p_public=true 또는 소유자/서비스롤이 아니면 민감정보(email/phone/address/birth_year) 리댁션
-- ---------------------------------------------------------------------------
create or replace function public.cv_data(p_profile uuid, p_public boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  pr        profiles%rowtype;
  v_email   text;
  eff_pub   boolean;
  based     text[];
  sections  jsonb := '[]'::jsonb;
  perf      jsonb;
  comp      jsonb;
  edu       jsonb;
  mcls      jsonb;
  rep       text[];
  teacher_c text;   -- 현재(재학중) 학적에 붙일 사사 교수
begin
  select * into pr from profiles where id = p_profile;
  if not found then
    return null;
  end if;

  -- 열람 권한: 소유자 또는 service_role 만 전체 열람, 그 외/명시적 public/불명 은 리댁션(안전 기본값)
  eff_pub := coalesce(p_public, false)
             or not (coalesce(auth.role(), '') = 'service_role'
                     or coalesce(auth.uid() = p_profile, false));

  if not eff_pub then
    select email into v_email from auth.users where id = p_profile;
  end if;

  -- based_in ← home_cities (slug) 를 도시명 + 국가코드로
  select array_agg(
           coalesce(c.name_en, hc.slug)
           || case when c.country_code is not null then ', ' || c.country_code else '' end
           order by hc.ord)
    into based
  from unnest(coalesce(pr.home_cities, '{}')) with ordinality hc(slug, ord)
  left join city c on c.id = hc.slug;

  -- 연주 (year_group)
  select jsonb_agg(jsonb_build_object(
           'year',         extract(year from a.activity_date)::int,
           'place',        a.location,
           'title',        a.title,
           'org',          a.organizer,
           'detail',       nullif(btrim(a.role), ''),
           'verification', public.cv_verify(a.verification)
         ) order by a.activity_date desc)
    into perf
  from activities a
  where a.user_id = p_profile and a.type = 'performance';

  -- 콩쿠르 (result_list)
  select jsonb_agg(jsonb_build_object(
           'period',       extract(year from a.activity_date)::int::text,
           'place',        a.location,
           'title',        a.title,
           'result',       a.prize,
           'verification', public.cv_verify(a.verification)
         ) order by a.activity_date desc)
    into comp
  from activities a
  where a.user_id = p_profile and a.type = 'competition';

  -- 사사 교수 (confirmed) — 현재 학적에 붙임
  select string_agg(coalesce(l.teacher_name, tp.real_name), ', ' order by l.created_at)
    into teacher_c
  from lineage l
  left join profiles tp on tp.id = l.teacher_id
  where l.student_id = p_profile and l.confirm_status = 'confirmed';

  -- 학력 (stack_edu) ← affiliations (학위과정)
  select jsonb_agg(jsonb_build_object(
           'period',      af.enrollment_year::text
                          || case when af.is_current then ' – Present' else '' end,
           'institution', af.institution_name,
           'degree',      public.cv_degree(af.course_type, pr.instrument),
           'teacher',     case when af.is_current then teacher_c else null end,
           'verification', null
         ) order by af.enrollment_year desc, af.is_current desc)
    into edu
  from affiliations af
  where af.user_id = p_profile;

  -- 마스터클래스 (two_up) ← activities type=education (날짜 있는 이벤트)
  select jsonb_agg(jsonb_build_object(
           'period',      extract(year from a.activity_date)::int::text,
           'place',       a.location,
           'institution', a.title,
           'teacher',     coalesce(nullif(btrim(a.role),''), a.organizer)
         ) order by a.activity_date desc)
    into mcls
  from activities a
  where a.user_id = p_profile and a.type = 'education';

  -- 레퍼토리 (inline) ← distinct program
  select array_agg(distinct btrim(a.program))
    into rep
  from activities a
  where a.user_id = p_profile
    and a.program is not null and btrim(a.program) <> '';

  -- 섹션 조립 (비어있지 않은 것만, 순서 고정)
  if perf is not null then
    sections := sections || jsonb_build_object(
      'kind','performance','layout','year_group','label','Professional Experience','entries',perf);
  end if;
  if comp is not null then
    sections := sections || jsonb_build_object(
      'kind','competition','layout','result_list','label','Competitions','entries',comp);
  end if;
  if edu is not null then
    sections := sections || jsonb_build_object(
      'kind','education','layout','stack_edu','label','Education','entries',edu);
  end if;
  if mcls is not null then
    sections := sections || jsonb_build_object(
      'kind','masterclass','layout','two_up','label','Masterclasses','entries',mcls);
  end if;
  if rep is not null and array_length(rep,1) > 0 then
    sections := sections || jsonb_build_object(
      'kind','repertoire','layout','inline','label','Selected Repertoire','items',to_jsonb(rep));
  end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'lang','en',
      'profile_url','fermata.app/p/' || pr.slug,
      'eyebrow', pr.eyebrow
    ),
    'person', jsonb_strip_nulls(jsonb_build_object(
      'name',       pr.real_name,
      'instrument', pr.instrument,
      'photo',      pr.avatar_url,
      'email',      v_email,
      'phone',      case when eff_pub then null else pr.phone end,
      'birth_year', case when eff_pub then null else pr.birth_year end,
      'address',    case when eff_pub then null else pr.address end,
      'based_in',   to_jsonb(coalesce(based, '{}'))
    )),
    'sections', sections
  );
end $$;

-- 웹 프로필(공개) RPC 는 anon 도 호출 가능 — 함수 내부에서 리댁션됨
grant execute on function public.cv_data(uuid, boolean) to anon, authenticated, service_role;

-- 공개 웹 프로필용 — slug 로 조회, 항상 리댁션된 JSON (render-service GET /p/{slug} 진입점)
create or replace function public.cv_data_by_slug(p_slug text)
returns jsonb
language sql
security definer
set search_path = public, auth
as $$
  select public.cv_data(id, true) from profiles where slug = p_slug;
$$;

grant execute on function public.cv_data_by_slug(text) to anon, authenticated, service_role;
