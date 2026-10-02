-- 0034: CV 전용 항목 (cv_entries)
--   기록(activities)과 분리된, CV에만 들어가는 간단 항목. 타입별 핵심 필드만.
--   cv_data 가 기존 활동/학적 기반 섹션에 병합(union)해서 렌더 → 내보내기/웹 자동 반영.
--   다국어는 기존 cv_i18n 오버레이를 source_kind='cv_entry' 로 그대로 적용.

-- ---------------------------------------------------------------------------
-- 1. cv_entries 테이블
-- ---------------------------------------------------------------------------
create table if not exists cv_entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  kind        text not null check (kind in ('performance','competition','education','masterclass')),
  year        int,          -- 연주/콩쿠르/마클 연도, 학력 시작연도(정렬용)
  period      text,         -- 학력 기간 표시 (예: '2020 – 2024')
  title       text,         -- 곡명/대회명
  org         text,         -- 주최 (연주)
  place       text,         -- 장소
  detail      text,         -- 짧은 설명 (연주)
  result      text,         -- 결과 (콩쿠르)
  institution text,         -- 기관 (학력/마스터클래스)
  degree      text,         -- 학위 (학력)
  teacher     text,         -- 사사/강사 (마스터클래스)
  created_at  timestamptz not null default now()
);
create index if not exists cv_entries_user_idx on cv_entries (user_id, kind);

alter table cv_entries enable row level security;
drop policy if exists cv_entries_owner on cv_entries;
create policy cv_entries_owner on cv_entries
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- cv_entries 변경도 CV 캐시 무효화
drop trigger if exists trg_cv_bump_entries on cv_entries;
create trigger trg_cv_bump_entries after insert or update or delete on cv_entries
  for each row execute function public.bump_cv_version();

-- cv_i18n 오버레이가 cv_entry 도 받도록
alter table cv_i18n drop constraint if exists cv_i18n_source_kind_check;
alter table cv_i18n add constraint cv_i18n_source_kind_check
  check (source_kind in ('activity', 'affiliation', 'profile', 'cv_entry'));

-- ---------------------------------------------------------------------------
-- 2. cv_data 재정의 — 각 섹션을 (활동/학적) ∪ (cv_entries) 로 병합
-- ---------------------------------------------------------------------------
create or replace function public.cv_data(p_profile uuid, p_public boolean default false, p_lang text default 'en')
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
  pov       jsonb;
  v_name    text;
  v_instr   text;
begin
  select * into pr from profiles where id = p_profile;
  if not found then return null; end if;

  eff_pub := coalesce(p_public, false)
             or not (coalesce(auth.role(), '') = 'service_role'
                     or coalesce(auth.uid() = p_profile, false));
  if not eff_pub then
    select email into v_email from auth.users where id = p_profile;
  end if;

  select patch into pov from cv_i18n
  where source_kind = 'profile' and source_id = p_profile and lang = p_lang;
  pov := coalesce(pov, '{}'::jsonb);

  v_name  := coalesce(pov->>'name', case when p_lang = 'en' then pr.name_en else null end, pr.real_name);
  v_instr := coalesce(pov->>'instrument',
                      case when p_lang = 'en' then public.instrument_en(pr.instrument) else null end,
                      pr.instrument);

  select array_agg(
           coalesce(c.name_en, hc.slug)
           || case when c.country_code is not null then ', ' || c.country_code else '' end
           order by hc.ord)
    into based
  from unnest(coalesce(pr.home_cities, '{}')) with ordinality hc(slug, ord)
  left join city c on c.id = hc.slug;

  select string_agg(coalesce(l.teacher_name, tp.real_name), ', ' order by l.created_at)
    into teacher_c
  from lineage l
  left join profiles tp on tp.id = l.teacher_id
  where l.student_id = p_profile and l.confirm_status = 'confirmed';

  -- 연주 (year_group) = activities ∪ cv_entries
  select jsonb_agg(e order by ey desc nulls last) into perf from (
    select extract(year from a.activity_date)::int as ey, jsonb_build_object(
             'year', extract(year from a.activity_date)::int,
             'place', coalesce(i.patch->>'place', a.location),
             'title', coalesce(i.patch->>'title', a.title),
             'org',   coalesce(i.patch->>'org', a.organizer),
             'detail',coalesce(i.patch->>'detail', nullif(btrim(a.role),'')),
             'verification', public.cv_verify(a.verification)) as e
    from activities a
    left join cv_i18n i on i.source_kind='activity' and i.source_id=a.id and i.lang=p_lang
    where a.user_id=p_profile and a.type='performance' and coalesce(i.include,true)
    union all
    select ce.year as ey, jsonb_build_object(
             'year', ce.year,
             'place', coalesce(ci.patch->>'place', ce.place),
             'title', coalesce(ci.patch->>'title', ce.title),
             'org',   coalesce(ci.patch->>'org', ce.org),
             'detail',coalesce(ci.patch->>'detail', ce.detail),
             'verification', null) as e
    from cv_entries ce
    left join cv_i18n ci on ci.source_kind='cv_entry' and ci.source_id=ce.id and ci.lang=p_lang
    where ce.user_id=p_profile and ce.kind='performance' and coalesce(ci.include,true)
  ) u;

  -- 콩쿠르 (result_list)
  select jsonb_agg(e order by ey desc nulls last) into comp from (
    select extract(year from a.activity_date)::int as ey, jsonb_build_object(
             'period', extract(year from a.activity_date)::int::text,
             'place', coalesce(i.patch->>'place', a.location),
             'title', coalesce(i.patch->>'title', a.title),
             'result',coalesce(i.patch->>'result', a.prize),
             'verification', public.cv_verify(a.verification)) as e
    from activities a
    left join cv_i18n i on i.source_kind='activity' and i.source_id=a.id and i.lang=p_lang
    where a.user_id=p_profile and a.type='competition' and coalesce(i.include,true)
    union all
    select ce.year as ey, jsonb_build_object(
             'period', ce.year::text,
             'place', coalesce(ci.patch->>'place', ce.place),
             'title', coalesce(ci.patch->>'title', ce.title),
             'result',coalesce(ci.patch->>'result', ce.result),
             'verification', null) as e
    from cv_entries ce
    left join cv_i18n ci on ci.source_kind='cv_entry' and ci.source_id=ce.id and ci.lang=p_lang
    where ce.user_id=p_profile and ce.kind='competition' and coalesce(ci.include,true)
  ) u;

  -- 학력 (stack_edu) = affiliations ∪ cv_entries(education)
  select jsonb_agg(e order by ey desc nulls last) into edu from (
    select af.enrollment_year as ey, jsonb_build_object(
             'period', af.enrollment_year::text || case when af.is_current then ' – Present' else '' end,
             'institution', coalesce(i.patch->>'institution', af.institution_name),
             'degree', coalesce(i.patch->>'degree',
                         case when p_lang='en' then public.cv_degree(af.course_type, public.instrument_en(pr.instrument)) else null end),
             'teacher', case when af.is_current then teacher_c else null end,
             'verification', null) as e
    from affiliations af
    left join cv_i18n i on i.source_kind='affiliation' and i.source_id=af.id and i.lang=p_lang
    where af.user_id=p_profile and coalesce(i.include,true)
    union all
    select ce.year as ey, jsonb_build_object(
             'period', coalesce(nullif(ce.period,''), ce.year::text),
             'institution', coalesce(ci.patch->>'institution', ce.institution),
             'degree', coalesce(ci.patch->>'degree', ce.degree),
             'teacher', null,
             'verification', null) as e
    from cv_entries ce
    left join cv_i18n ci on ci.source_kind='cv_entry' and ci.source_id=ce.id and ci.lang=p_lang
    where ce.user_id=p_profile and ce.kind='education' and coalesce(ci.include,true)
  ) u;

  -- 마스터클래스 (two_up) = activities(education) ∪ cv_entries(masterclass)
  select jsonb_agg(e order by ey desc nulls last) into mcls from (
    select extract(year from a.activity_date)::int as ey, jsonb_build_object(
             'period', extract(year from a.activity_date)::int::text,
             'place', coalesce(i.patch->>'place', a.location),
             'institution', coalesce(i.patch->>'institution', a.title),
             'teacher', coalesce(i.patch->>'teacher', nullif(btrim(a.role),''), a.organizer)) as e
    from activities a
    left join cv_i18n i on i.source_kind='activity' and i.source_id=a.id and i.lang=p_lang
    where a.user_id=p_profile and a.type='education' and coalesce(i.include,true)
    union all
    select ce.year as ey, jsonb_build_object(
             'period', ce.year::text,
             'place', coalesce(ci.patch->>'place', ce.place),
             'institution', coalesce(ci.patch->>'institution', ce.institution),
             'teacher', coalesce(ci.patch->>'teacher', ce.teacher)) as e
    from cv_entries ce
    left join cv_i18n ci on ci.source_kind='cv_entry' and ci.source_id=ce.id and ci.lang=p_lang
    where ce.user_id=p_profile and ce.kind='masterclass' and coalesce(ci.include,true)
  ) u;

  select array_agg(r order by ord) into rep
  from unnest(coalesce(pr.repertoire, '{}')) with ordinality u(r, ord)
  where btrim(r) <> '';

  if perf is not null then sections := sections || jsonb_build_object('kind','performance','layout','year_group','label','Professional Experience','entries',perf); end if;
  if comp is not null then sections := sections || jsonb_build_object('kind','competition','layout','result_list','label','Competitions','entries',comp); end if;
  if edu  is not null then sections := sections || jsonb_build_object('kind','education','layout','stack_edu','label','Education','entries',edu); end if;
  if mcls is not null then sections := sections || jsonb_build_object('kind','masterclass','layout','two_up','label','Masterclasses','entries',mcls); end if;
  if rep is not null and array_length(rep,1) > 0 then sections := sections || jsonb_build_object('kind','repertoire','layout','inline','label','Selected Repertoire','items',to_jsonb(rep)); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'lang', p_lang,
      'profile_url', 'fermata.app/p/' || pr.slug,
      'eyebrow', coalesce(pov->>'eyebrow', pr.eyebrow),
      'available_langs', to_jsonb(array['ko'] || pr.profile_langs)
    ),
    'person', jsonb_strip_nulls(jsonb_build_object(
      'name', v_name, 'instrument', v_instr, 'bio', coalesce(pov->>'bio', pr.bio),
      'photo', pr.avatar_url, 'email', v_email,
      'phone', case when eff_pub then null else pr.phone end,
      'birth_year', case when eff_pub then null else pr.birth_year end,
      'address', case when eff_pub then null else pr.address end,
      'based_in', to_jsonb(coalesce(based, '{}'))
    )),
    'sections', sections
  );
end $$;

grant execute on function public.cv_data(uuid, boolean, text) to anon, authenticated, service_role;
