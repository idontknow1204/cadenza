-- Rich career details: concrete contribution and supporting links/media.

alter table public.careers
  add column if not exists contribution text,
  add column if not exists link_url text,
  add column if not exists media_url text;
