-- 0046: CV 캐시 무효화 — 폰트 크기/굵기 통일 반영
--   마스터클래스 섹션 폰트 크기를 다른 섹션과 동일하게 수정(0046 템플릿 배포)한 뒤
--   기존 캐시된 PDF를 무효화한다.

update profiles set cv_version = cv_version + 1;
