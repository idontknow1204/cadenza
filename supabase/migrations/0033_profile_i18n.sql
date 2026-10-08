-- 0033: 다국어 프로필 (multilingual profile)
--   cv_i18n 을 lang 축으로 일반화 → 프로필/활동/학적을 언어별로 오버레이.
--   베이스는 한국어 원문(메인 테이블). en/de 는 오버레이. 없으면 원문 폴백.
--   기존 영어 CV 는 lang='en' 으로 그대로 동작.

-- ---------------------------------------------------------------------------
-- 1. cv_i18n 에 lang 추가 (범용 로컬라이제이션 레이어로 승격)
-- ---------------------------------------------------------------------------
alter table cv_i18n add column if not exists lang text not null default 'en';

alter table cv_i18n drop constraint if exists cv_i18n_pkey;
alter table cv_i18n add primary key (source_kind, source_id, lang);

alter table cv_i18n drop constraint if exists cv_i18n_source_kind_check;
alter table cv_i18n add constraint cv_i18n_source_kind_check
  check (source_kind in ('activity', 'affiliation', 'profile'));

-- 프로필이 제공하는 오버레이 언어 목록 (베이스 ko 는 암묵적). 언어 스위처·가용성에 사용.
alter table profiles add column if not exists profile_langs text[] not null default '{}';

-- ---------------------------------------------------------------------------
-- 2. cv_data 를 lang 인자로 일반화 (2-arg → 3-arg)
--    name/instrument/bio/eyebrow 는 profile-level 오버레이, 없으면 폴백.
--    항목(활동/학적)은 해당 lang 오버레이, 없으면 한국어 원문.
-- ---------------------------------------------------------------------------
drop function if exists public.cv_data(uuid, boolean);

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
  pov       jsonb;          -- profile-level 오버레이 patch (name/bio/instrument/eyebrow)
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

  select patch into pov
  from cv_i18n
  where source_kind = 'profile' and source_id = p_profile and lang = p_lang;
  pov := coalesce(pov, '{}'::jsonb);

  -- name: 오버레이 → (en 한정) name_en → 원문
  v_name := coalesce(pov->>'name', case when p_lang = 'en' then pr.name_en else null end, pr.real_name);
  -- instrument: 오버레이 → (en 한정) 통제어휘 매핑 → 원문
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

  -- 연주 (year_group)
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
  left join cv_i18n i on i.source_kind = 'activity' and i.source_id = a.id and i.lang = p_lang
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
  left join cv_i18n i on i.source_kind = 'activity' and i.source_id = a.id and i.lang = p_lang
  where a.user_id = p_profile and a.type = 'competition' and coalesce(i.include, true);

  select string_agg(coalesce(l.teacher_name, tp.real_name), ', ' order by l.created_at)
    into teacher_c
  from lineage l
  left join profiles tp on tp.id = l.teacher_id
  where l.student_id = p_profile and l.confirm_status = 'confirmed';

  -- 학력 (stack_edu)
  select jsonb_agg(jsonb_build_object(
           'period',       af.enrollment_year::text
                           || case when af.is_current then ' – Present' else '' end,
           'institution',  coalesce(i.patch->>'institution', af.institution_name),
           'degree',       coalesce(i.patch->>'degree',
                             case when p_lang = 'en'
                                  then public.cv_degree(af.course_type, public.instrument_en(pr.instrument))
                                  else null end),
           'teacher',      case when af.is_current then teacher_c else null end,
           'verification', null
         ) order by af.enrollment_year desc, af.is_current desc)
    into edu
  from affiliations af
  left join cv_i18n i on i.source_kind = 'affiliation' and i.source_id = af.id and i.lang = p_lang
  where af.user_id = p_profile and coalesce(i.include, true);

  -- 마스터클래스 (two_up)
  select jsonb_agg(jsonb_build_object(
           'period',      extract(year from a.activity_date)::int::text,
           'place',       coalesce(i.patch->>'place', a.location),
           'institution', coalesce(i.patch->>'institution', a.title),
           'teacher',     coalesce(i.patch->>'teacher', nullif(btrim(a.role),''), a.organizer)
         ) order by a.activity_date desc)
    into mcls
  from activities a
  left join cv_i18n i on i.source_kind = 'activity' and i.source_id = a.id and i.lang = p_lang
  where a.user_id = p_profile and a.type = 'education' and coalesce(i.include, true);

  select array_agg(r order by ord)
    into rep
  from unnest(coalesce(pr.repertoire, '{}')) with ordinality u(r, ord)
  where btrim(r) <> '';

  if perf is not null then
    sections := sections || jsonb_build_object('kind','performance','layout','year_group','label','Professional Experience','entries',perf); end if;
  if comp is not null then
    sections := sections || jsonb_build_object('kind','competition','layout','result_list','label','Competitions','entries',comp); end if;
  if edu is not null then
    sections := sections || jsonb_build_object('kind','education','layout','stack_edu','label','Education','entries',edu); end if;
  if mcls is not null then
    sections := sections || jsonb_build_object('kind','masterclass','layout','two_up','label','Masterclasses','entries',mcls); end if;
  if rep is not null and array_length(rep,1) > 0 then
    sections := sections || jsonb_build_object('kind','repertoire','layout','inline','label','Selected Repertoire','items',to_jsonb(rep)); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'lang', p_lang,
      'profile_url', 'fermata.app/p/' || pr.slug,
      'eyebrow', coalesce(pov->>'eyebrow', pr.eyebrow),
      'available_langs', to_jsonb(array['ko'] || pr.profile_langs)
    ),
    'person', jsonb_strip_nulls(jsonb_build_object(
      'name',       v_name,
      'instrument', v_instr,
      'bio',        coalesce(pov->>'bio', pr.bio),
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

grant execute on function public.cv_data(uuid, boolean, text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. cv_data_by_slug 도 lang 인자로 (방문자 언어 해석용)
-- ---------------------------------------------------------------------------
drop function if exists public.cv_data_by_slug(text);

create or replace function public.cv_data_by_slug(p_slug text, p_lang text default 'en')
returns jsonb
language sql
security definer
set search_path = public, auth
as $$
  select public.cv_data(id, true, p_lang) from profiles where slug = p_slug;
$$;

grant execute on function public.cv_data_by_slug(text, text) to anon, authenticated, service_role;
