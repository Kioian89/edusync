-- Run once in the Supabase SQL Editor after creating the private
-- "activity-documents" bucket and configuring Firebase third-party auth.

-- 1. Ensure auth.uid() safely handles non-UUID third-party tokens (Firebase UIDs)
-- without throwing "invalid input syntax for type uuid".
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select case
    when nullif(current_setting('request.jwt.claim.sub', true), '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
    when (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid
    else null
  end;
$$;

-- 2. Drop existing policies to allow clean re-application
drop policy if exists "Class members can read activity documents" on storage.objects;
drop policy if exists "Teachers can upload their class activity documents" on storage.objects;
drop policy if exists "Students can upload their own class submissions" on storage.objects;
drop policy if exists "Teachers can delete their class activity documents" on storage.objects;
drop policy if exists "Students can delete their own class submissions" on storage.objects;

-- 3. Recreate policies using (auth.jwt() ->> 'sub') instead of auth.uid()
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
    or (storage.foldername(name))[4] = (auth.jwt() ->> 'sub')
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
  and (storage.foldername(name))[3] = (auth.jwt() ->> 'sub')
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
  and (storage.foldername(name))[4] = (auth.jwt() ->> 'sub')
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
  and (storage.foldername(name))[3] = (auth.jwt() ->> 'sub')
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
  and (storage.foldername(name))[4] = (auth.jwt() ->> 'sub')
);
