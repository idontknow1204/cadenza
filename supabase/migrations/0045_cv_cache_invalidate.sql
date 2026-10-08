-- 0045: CV 캐시 전체 무효화
--   SQL 함수(0044)가 바뀌었지만 cv_version은 그대로라 기존 PDF가 계속 캐시 히트됨.
--   모든 프로필의 cv_version을 한 칸 올려서 다음 내보내기 시 새 PDF를 강제 재생성한다.

update profiles set cv_version = cv_version + 1;
