-- 0057: CV 관련 필드 변경 시 cv_version 자동 증가
--   저장 후 내보내기 시 항상 최신 데이터로 재렌더링되도록 캐시를 자동 무효화한다.
--   대상 필드: name_en, eyebrow, birth_date, phone, address, cv_photo_url, repertoire

create or replace function public.bump_cv_version_on_change()
returns trigger language plpgsql as $$
begin
  if (new.name_en      is distinct from old.name_en      or
      new.eyebrow      is distinct from old.eyebrow      or
      new.birth_date   is distinct from old.birth_date   or
      new.phone        is distinct from old.phone        or
      new.address      is distinct from old.address      or
      new.cv_photo_url is distinct from old.cv_photo_url or
      new.repertoire   is distinct from old.repertoire) then
    new.cv_version := coalesce(old.cv_version, 0) + 1;
  end if;
  return new;
end $$;

drop trigger if exists trg_bump_cv_version on profiles;
create trigger trg_bump_cv_version
before update on profiles
for each row execute function public.bump_cv_version_on_change();
