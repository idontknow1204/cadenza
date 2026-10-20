-- 0060: 인앱 공개 프로필 다국어 (LinkedIn 방식)
--
--   PublicProfileView 가 방문자 언어로 프로필을 보여주기 위한 읽기 경로.
--   - cv_i18n 오버레이를 career/award 까지 확장 (기존 activity/affiliation/profile 유지)
--   - profile_i18n(user, lang) RPC: 방문자가 작성자의 오버레이를 읽을 수 있도록
--     SECURITY DEFINER 로 RLS 우회. (cv_i18n RLS 는 소유자 전용이라 직접 조회 불가)

-- ---------------------------------------------------------------------------
-- 1. 오버레이 대상에 career/award 추가
-- ---------------------------------------------------------------------------
alter table cv_i18n drop constraint if exists cv_i18n_source_kind_check;
alter table cv_i18n add constraint cv_i18n_source_kind_check
  check (source_kind in ('activity', 'affiliation', 'profile', 'cv_entry', 'career', 'award'));

-- ---------------------------------------------------------------------------
-- 2. 공개 오버레이 읽기 RPC
--    반환: { "<kind>:<uuid>": { "<field>": "<번역>", ... }, ... }
--    profile-level 오버레이 키는 "profile:<user_uuid>".
--    include 플래그는 CV 전용(항목 숨김)이므로 프로필 번역에는 적용하지 않음.
-- ---------------------------------------------------------------------------
create or replace function public.profile_i18n(p_user uuid, p_lang text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_object_agg(source_kind || ':' || source_id::text, patch),
    '{}'::jsonb)
  from cv_i18n
  where user_id = p_user and lang = p_lang;
$$;

grant execute on function public.profile_i18n(uuid, text) to anon, authenticated, service_role;
