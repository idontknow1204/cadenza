-- 0032: Fermata CV — PDF 캐시용 비공개 Storage 버킷
-- 키 규칙: cv/{slug}/{cv_version}.pdf  (cv_version 이 오르면 새 키 → 자동 무효화)
-- 업로드/조회는 Edge Function(service_role)만. 사용자에겐 signed URL 로 전달.

insert into storage.buckets (id, name, public)
values ('cv', 'cv', false)
on conflict (id) do nothing;
