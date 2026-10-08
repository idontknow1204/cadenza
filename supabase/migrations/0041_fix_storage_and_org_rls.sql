-- 0041: Fix two RLS bugs
--
-- 1) user-files 버킷 INSERT 정책 누락 → "new row violates row-level security policy"
--    CV PDF 업로드가 auth 사용자가 자신의 폴더에만 쓸 수 있도록 허용.
--
-- 2) org_admins_select 정책의 자기참조 재귀 → "infinite recursion detected in policy for relation org_admins"
--    org_admins 행을 SELECT 할 때 policy 가 다시 org_admins 를 SELECT → 무한루프.
--    단순히 user_id = auth.uid() 조건으로 교체해 재귀를 제거한다.
--    (org_admins_insert / delete 내부의 EXISTS 는 user_id 필터가 동일하게 적용되므로 정상 동작)

-- ────────────────────────────────────────────────────────────
-- 1. user-files 버킷 및 Storage RLS 정책
-- ────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('user-files', 'user-files', true)
on conflict (id) do nothing;

-- 이미 존재할 경우 중복 방지
drop policy if exists "user_files_upload" on storage.objects;
drop policy if exists "user_files_update" on storage.objects;
drop policy if exists "user_files_delete" on storage.objects;

-- 본인 폴더({userId}/*)에만 쓰기/덮어쓰기/삭제 허용
create policy "user_files_upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'user-files'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "user_files_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'user-files'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "user_files_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'user-files'
    and (storage.foldername(name))[1] = auth.uid()::text);

-- ────────────────────────────────────────────────────────────
-- 2. org_admins 재귀 SELECT 정책 수정
-- ────────────────────────────────────────────────────────────
drop policy if exists org_admins_select on public.org_admins;

-- 자기 자신의 admin 행만 조회 가능 (재귀 없음)
-- activities_insert / orgs_update 에서 EXISTS(SELECT 1 FROM org_admins WHERE user_id = auth.uid())
-- 형태로 호출되므로 올바르게 동작한다.
create policy org_admins_select on public.org_admins
  for select to authenticated
  using (user_id = auth.uid());
