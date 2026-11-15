-- Run once in the Supabase SQL Editor after creating the private
-- "activity-documents" bucket and configuring Firebase third-party auth.

create policy "Class members can read activity documents"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'activity-documents'
  and (storage.foldername(name))[1] in (
    'activity_attachments',
    'activity_submissions'
  )
  and coalesce(auth.jwt() -> 'class_ids', '[]'::jsonb)
    ? (storage.foldername(name))[2]
  and auth.jwt() ->> 'edusync_role' in ('teacher', 'student')
  and (
    (storage.foldername(name))[1] <> 'activity_submissions'
    or auth.jwt() ->> 'edusync_role' = 'teacher'
    or (storage.foldername(name))[4] = auth.uid()::text
  )
);

create policy "Teachers can upload their class activity documents"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'activity-documents'
  and (storage.foldername(name))[1] = 'activity_attachments'
  and coalesce(auth.jwt() -> 'class_ids', '[]'::jsonb)
    ? (storage.foldername(name))[2]
  and auth.jwt() ->> 'edusync_role' = 'teacher'
  and (storage.foldername(name))[3] = auth.uid()::text
);

create policy "Students can upload their own class submissions"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'activity-documents'
  and (storage.foldername(name))[1] = 'activity_submissions'
  and coalesce(auth.jwt() -> 'class_ids', '[]'::jsonb)
    ? (storage.foldername(name))[2]
  and auth.jwt() ->> 'edusync_role' = 'student'
  and (storage.foldername(name))[4] = auth.uid()::text
);

create policy "Teachers can delete their class activity documents"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'activity-documents'
  and (storage.foldername(name))[1] = 'activity_attachments'
  and coalesce(auth.jwt() -> 'class_ids', '[]'::jsonb)
    ? (storage.foldername(name))[2]
  and auth.jwt() ->> 'edusync_role' = 'teacher'
  and (storage.foldername(name))[3] = auth.uid()::text
);

create policy "Students can delete their own class submissions"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'activity-documents'
  and (storage.foldername(name))[1] = 'activity_submissions'
  and coalesce(auth.jwt() -> 'class_ids', '[]'::jsonb)
    ? (storage.foldername(name))[2]
  and auth.jwt() ->> 'edusync_role' = 'student'
  and (storage.foldername(name))[4] = auth.uid()::text
);
