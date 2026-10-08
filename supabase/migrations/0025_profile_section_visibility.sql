-- Previously the six core sections were always visible. Preserve that layout
-- while making visible_sections the complete list for both profile screens.
begin;

update public.profiles
set visible_sections = array['bio', 'activities', 'career', 'education', 'awards', 'languages']::text[]
    || array(select section from unnest(visible_sections) as section
             where section not in ('bio', 'activities', 'career', 'education', 'awards', 'languages'));

alter table public.profiles
    alter column visible_sections set default '{bio,activities,career,education,awards,languages}'::text[];

commit;
