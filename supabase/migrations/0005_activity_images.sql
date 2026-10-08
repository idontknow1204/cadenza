-- Activity image attachments (up to 5 per activity)

alter table public.activities
  add column if not exists image_urls text[] not null default '{}';

-- Storage bucket for activity images (public read, owner-scoped write)
insert into storage.buckets (id, name, public)
  values ('activity-images', 'activity-images', true)
  on conflict do nothing;

create policy "activity_images_read" on storage.objects
  for select using (bucket_id = 'activity-images');

create policy "activity_images_upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'activity-images'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "activity_images_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'activity-images'
    and (storage.foldername(name))[1] = auth.uid()::text);
