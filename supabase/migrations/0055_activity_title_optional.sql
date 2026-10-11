-- Activity cards no longer expose a separate title. Keep the column for
-- backward compatibility with existing rows and clients, but allow new apps
-- to persist an empty value without inventing user-visible placeholder text.
alter table public.activities
  drop constraint if exists activities_title_check;

alter table public.activities
  alter column title set default '';
