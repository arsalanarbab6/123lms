-- =====================================================================
-- CyberEdge Academy — Schema Update v2 (Phase 2 fields)
-- Run this in Supabase SQL Editor AFTER running database_schema.sql
-- =====================================================================

-- Add new columns to profiles table for Phase 2 pages
alter table public.profiles
  add column if not exists city text,
  add column if not exists date_of_birth date,
  add column if not exists gender text,
  add column if not exists district text,
  add column if not exists education_degree text,
  add column if not exists education_field text,
  add column if not exists education_institution text,
  add column if not exists graduation_year int,
  add column if not exists is_final_year boolean default false,
  add column if not exists linkedin text,
  add column if not exists portfolio text,
  add column if not exists twitter text,
  add column if not exists skills text[],
  add column if not exists bio text,
  add column if not exists updated_at timestamp with time zone default now();

-- Add course_id column to applications (so admin can assign a course)
alter table public.applications
  add column if not exists course_id uuid references public.courses(id);

-- Create Supabase Storage bucket for documents
-- Note: Run this in Supabase Dashboard -> Storage -> New bucket
-- Bucket name: documents
-- Public: false (private)
-- The SQL below creates the bucket policy once it exists:

-- Allow authenticated users to upload their own documents
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict do nothing;

create policy "Users can upload own documents"
on storage.objects for insert
with check (bucket_id = 'documents' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "Users can read own documents"
on storage.objects for select
using (bucket_id = 'documents' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "Admins can read all documents"
on storage.objects for select
using (
  bucket_id = 'documents' and
  exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor'))
);

-- =====================================================================
-- DONE. After running this, Phase 2 profile creation & document upload
-- pages will work correctly.
-- =====================================================================
