-- 0031: Fermata CV — 영어화(②) + 레퍼토리/큐레이션(③)
--   ② instrument 통제어휘는 instrument_i18n 매핑, 자유텍스트(곡명·기관명 등)는
--      cv_i18n 오버레이(jsonb patch)로 사용자가 확정한 영어를 덮어씀
--   ③ 레퍼토리는 activities.program 파생을 폐기하고 profiles.repertoire(큐레이션)로
--   cv_i18n.include=false 로 개별 항목을 CV에서 제외 가능

-- ---------------------------------------------------------------------------
-- 1. 레퍼토리: 프로필 레벨 큐레이션 목록
-- ---------------------------------------------------------------------------
alter table profiles
  add column if not exists repertoire text[] not null default '{}',
  add column if not exists name_en    text;   -- CV용 로마자 이름 (없으면 real_name)

-- ---------------------------------------------------------------------------
-- 2. instrument 통제어휘 매핑 (한글 → 영어)
-- ---------------------------------------------------------------------------
create table if not exists instrument_i18n (
  ko text primary key,
  en text not null
);

insert into instrument_i18n (ko, en) values
  ('바이올린','Violin'), ('비올라','Viola'), ('첼로','Cello'),
  ('더블베이스','Double Bass'), ('콘트라베이스','Double Bass'),
  ('피아노','Piano'), ('오르간','Organ'), ('하프시코드','Harpsichord'),
  ('플루트','Flute'), ('오보에','Oboe'), ('클라리넷','Clarinet'),
  ('바순','Bassoon'), ('파곳','Bassoon'),
  ('호른','Horn'), ('트럼펫','Trumpet'), ('트롬본','Trombone'), ('튜바','Tuba'),
  ('타악기','Percussion'), ('하프','Harp'), ('기타','Guitar'),
  ('색소폰','Saxophone'), ('성악','Voice'), ('작곡','Composition'),
  ('지휘','Conducting')
on conflict (ko) do update set en = excluded.en;

-- 매핑 있으면 영어, 없으면 원문 유지 (라틴 입력은 그대로 통과)
create or replace function public.instrument_en(txt text)
returns text language sql stable as $$
  select coalesce((select en from instrument_i18n where ko = btrim(txt)), txt);
$$;

-- ---------------------------------------------------------------------------
-- 3. cv_i18n 오버레이 사이드카 — CV 전용 영어 확정 + 큐레이션
--    source_kind: 'activity' | 'affiliation'
--    patch: 출력 필드명(title/org/place/detail/result/institution/teacher/degree)을 키로
-- ---------------------------------------------------------------------------
create table if not exists cv_i18n (
  source_kind text not null check (source_kind in ('activity','affiliation')),
  source_id   uuid not null,
  user_id     uuid not null references profiles(id) on delete cascade,
  patch       jsonb not null default '{}'::jsonb,
  include     boolean not null default true,
  updated_at  timestamptz not null default now(),
  primary key (source_kind, source_id)
);
create index if not exists cv_i18n_user_idx on cv_i18n (user_id);

alter table cv_i18n enable row level security;
drop policy if exists cv_i18n_owner on cv_i18n;
create policy cv_i18n_owner on cv_i18n
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 오버레이/레퍼토리 변경도 CV 캐시 무효화
drop trigger if exists trg_cv_bump_i18n on cv_i18n;
create trigger trg_cv_bump_i18n after insert or update or delete on cv_i18n
  for each row execute function public.bump_cv_version();

-- ---------------------------------------------------------------------------
-- 4. cv_data 재정의 — 오버레이 coalesce, include 필터, 레퍼토리/instrument 영어화
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
  teacher_c text;
begin
  select * into pr from profiles where id = p_profile;
  if not found then
    return null;
  end if;

  eff_pub := coalesce(p_public, false)
             or not (coalesce(auth.role(), '') = 'service_role'
                     or coalesce(auth.uid() = p_profile, false));

  if not eff_pub then
    select email into v_email from auth.users where id = p_profile;
  end if;

  select array_agg(
           coalesce(c.name_en, hc.slug)
           || case when c.country_code is not null then ', ' || c.country_code else '' end
           order by hc.ord)
    into based
  from unnest(coalesce(pr.home_cities, '{}')) with ordinality hc(slug, ord)
  left join city c on c.id = hc.slug;

  -- 연주 (year_group) — 오버레이 적용 + include 필터
  select jsonb_agg(jsonb_build_object(
           'year',         extract(year from a.activity_date)::int,
           'place',        coalesce(i.patch->>'place',  a.location),
           'title',        coalesce(i.patch->>'title',  a.title),
           'org',          coalesce(i.patch->>'org',    a.organizer),
           'detail',       coalesce(i.patch->>'detail', nullif(btrim(a.role), '')),
           'verification', public.cv_verify(a.verification)
         ) order by a.activity_date desc)
    into perf
  from activities a
  left join cv_i18n i on i.source_kind = 'activity' and i.source_id = a.id
  where a.user_id = p_profile and a.type = 'performance' and coalesce(i.include, true);

  -- 콩쿠르 (result_list)
  select jsonb_agg(jsonb_build_object(
           'period',       extract(year from a.activity_date)::int::text,
           'place',        coalesce(i.patch->>'place',  a.location),
           'title',        coalesce(i.patch->>'title',  a.title),
           'result',       coalesce(i.patch->>'result', a.prize),
           'verification', public.cv_verify(a.verification)
         ) order by a.activity_date desc)
    into comp
  from activities a
  left join cv_i18n i on i.source_kind = 'activity' and i.source_id = a.id
  where a.user_id = p_profile and a.type = 'competition' and coalesce(i.include, true);

  select string_agg(coalesce(l.teacher_name, tp.real_name), ', ' order by l.created_at)
    into teacher_c
  from lineage l
  left join profiles tp on tp.id = l.teacher_id
  where l.student_id = p_profile and l.confirm_status = 'confirmed';

  -- 학력 (stack_edu) ← affiliations
  select jsonb_agg(jsonb_build_object(
           'period',       af.enrollment_year::text
                           || case when af.is_current then ' – Present' else '' end,
           'institution',  coalesce(i.patch->>'institution', af.institution_name),
           'degree',       coalesce(i.patch->>'degree',
                             public.cv_degree(af.course_type, public.instrument_en(pr.instrument))),
           'teacher',      case when af.is_current then teacher_c else null end,
           'verification', null
         ) order by af.enrollment_year desc, af.is_current desc)
    into edu
  from affiliations af
  left join cv_i18n i on i.source_kind = 'affiliation' and i.source_id = af.id
  where af.user_id = p_profile and coalesce(i.include, true);

  -- 마스터클래스 (two_up) ← activities type=education
  select jsonb_agg(jsonb_build_object(
           'period',      extract(year from a.activity_date)::int::text,
           'place',       coalesce(i.patch->>'place', a.location),
           'institution', coalesce(i.patch->>'institution', a.title),
           'teacher',     coalesce(i.patch->>'teacher', nullif(btrim(a.role),''), a.organizer)
         ) order by a.activity_date desc)
    into mcls
  from activities a
  left join cv_i18n i on i.source_kind = 'activity' and i.source_id = a.id
  where a.user_id = p_profile and a.type = 'education' and coalesce(i.include, true);

  -- 레퍼토리 (inline) ← 프로필 큐레이션 목록 (program 파생 폐기)
  select array_agg(r order by ord)
    into rep
  from unnest(coalesce(pr.repertoire, '{}')) with ordinality u(r, ord)
  where btrim(r) <> '';

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
      'name',       coalesce(pr.name_en, pr.real_name),
      'instrument', public.instrument_en(pr.instrument),
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
