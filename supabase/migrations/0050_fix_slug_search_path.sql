-- 0050: Fix ensure_profile_slug search_path
--
-- handle_new_user runs with `security definer set search_path = ''`.
-- Any trigger fired inside it inherits that empty search_path.
-- ensure_profile_slug() referenced `profiles` without a schema prefix, so
-- the while-exists loop failed with "relation 'profiles' does not exist"
-- for any user whose name contains at least one Latin character (the
-- pure-Korean name path returns early and never reaches that query).
-- Fix: add `set search_path = public` to the function and qualify the
-- table reference to make it resilient regardless of the calling context.

create or replace function public.ensure_profile_slug()
returns trigger
language plpgsql
set search_path = public
as $$
declare base text; cand text; n int := 0;
begin
  if new.slug is not null and btrim(new.slug) <> '' then
    return new;
  end if;
  base := nullif(public.slugify(new.real_name), '');
  if base is null then
    new.slug := 'u-' || public.slug_token(new.id, 10);
    return new;
  end if;
  cand := base;
  while exists (select 1 from public.profiles where slug = cand and id <> new.id) loop
    n := n + 1;
    cand := base || '-' || public.slug_token(new.id, 4 + n);
  end loop;
  new.slug := cand;
  return new;
end $$;
