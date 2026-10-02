-- Typed activity columns: program (repertoire/tracklist), prize (competition result), organizer

alter table public.activities
  add column if not exists program   text,   -- 레퍼토리 (연주) / 수록곡 (음반)
  add column if not exists prize     text,   -- 수상결과 (경연)
  add column if not exists organizer text;   -- 주최 (연주/경연)
