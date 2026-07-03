-- =====================================================================
-- CyberEdge Academy — FINAL COMPLETE DATABASE SCHEMA
-- =====================================================================
-- INSTRUCTIONS (Beginner ke liye step by step):
--
-- STEP 1: Pehle purana database drop karo (agar pehle se kuch bana hua hai)
--   Supabase → SQL Editor → New Query → yeh paste karo aur RUN karo:
--
--   drop schema public cascade; create schema public;
--
-- STEP 2: Phir yeh poora file paste karo SQL Editor mein aur RUN karo
-- STEP 3: Authentication → Sign In/Providers → Email → "Confirm email" OFF karo
-- =====================================================================

-- 1. PROFILES (har user ka profile — signup pe auto-create hota hai)
create table public.profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  full_name        text,
  email            text,
  phone            text,
  role             text not null default 'student' check (role in ('student','instructor','admin')),
  avatar_url       text,
  city             text,
  date_of_birth    date,
  gender           text,
  district         text,
  education_degree      text,
  education_field       text,
  education_institution text,
  graduation_year  int,
  is_final_year    boolean default false,
  linkedin         text,
  portfolio        text,
  twitter          text,
  skills           text[],
  bio              text,
  job_title        text,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'role', 'student')
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2. COURSES
create table public.courses (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  description     text,
  category        text,
  level           text default 'Intermediate',
  duration_weeks  int default 12,
  contact_hours   int default 144,
  image_url       text,
  is_published    boolean default true,
  created_by      uuid references public.profiles(id),
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- 3. ENROLLMENTS
create table public.enrollments (
  id               uuid primary key default gen_random_uuid(),
  student_id       uuid references public.profiles(id) on delete cascade,
  course_id        uuid references public.courses(id) on delete cascade,
  progress_percent int default 0,
  status           text default 'active' check (status in ('active','completed','dropped')),
  enrolled_at      timestamptz default now(),
  unique (student_id, course_id)
);

-- 4. APPLICATIONS
create table public.applications (
  id            uuid primary key default gen_random_uuid(),
  applicant_id  uuid references public.profiles(id) on delete cascade,
  course_id     uuid references public.courses(id),
  status        text default 'pending' check (status in ('pending','screening','shortlisted','rejected','accepted')),
  score         int,
  notes         text,
  submitted_at  timestamptz default now(),
  reviewed_at   timestamptz,
  reviewed_by   uuid references public.profiles(id)
);

-- 5. ASSIGNMENTS
create table public.assignments (
  id          uuid primary key default gen_random_uuid(),
  course_id   uuid references public.courses(id) on delete cascade,
  title       text not null,
  description text,
  due_date    timestamptz,
  max_points  int default 100,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz default now()
);

-- 6. SUBMISSIONS
create table public.submissions (
  id            uuid primary key default gen_random_uuid(),
  assignment_id uuid references public.assignments(id) on delete cascade,
  student_id    uuid references public.profiles(id) on delete cascade,
  file_url      text,
  submitted_at  timestamptz default now(),
  grade         int,
  feedback      text,
  graded_by     uuid references public.profiles(id),
  graded_at     timestamptz,
  unique (assignment_id, student_id)
);

-- 7. ATTENDANCE
create table public.attendance (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid references public.profiles(id) on delete cascade,
  course_id    uuid references public.courses(id) on delete cascade,
  session_date date not null,
  session_title text,
  status       text default 'present' check (status in ('present','absent','late')),
  marked_by    uuid references public.profiles(id),
  marked_at    timestamptz default now()
);

-- 8. ANNOUNCEMENTS
create table public.announcements (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  message     text,
  category    text default 'general',
  course_id   uuid references public.courses(id),
  created_by  uuid references public.profiles(id),
  is_global   boolean default false,
  created_at  timestamptz default now()
);

-- 9. NOTIFICATIONS
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.profiles(id) on delete cascade,
  title      text not null,
  message    text,
  category   text default 'system',
  is_read    boolean default false,
  created_at timestamptz default now()
);

-- 10. SESSIONS (live sessions / classes)
create table public.sessions (
  id          uuid primary key default gen_random_uuid(),
  course_id   uuid references public.courses(id) on delete cascade,
  title       text not null,
  description text,
  session_date timestamptz,
  duration_minutes int default 90,
  meet_link   text,
  recording_url text,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz default now()
);

-- =====================================================================
-- ROW LEVEL SECURITY
-- =====================================================================
alter table public.profiles      enable row level security;
alter table public.courses       enable row level security;
alter table public.enrollments   enable row level security;
alter table public.applications  enable row level security;
alter table public.assignments   enable row level security;
alter table public.submissions   enable row level security;
alter table public.attendance    enable row level security;
alter table public.announcements enable row level security;
alter table public.notifications enable row level security;
alter table public.sessions      enable row level security;

-- PROFILES
create policy "profiles_read_all"   on public.profiles for select using (true);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- COURSES: public can view published; admin/instructor can manage
create policy "courses_view_published" on public.courses for select using (is_published = true);
create policy "courses_admin_select"   on public.courses for select using (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));
create policy "courses_admin_insert"   on public.courses for insert with check (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));
create policy "courses_admin_update"   on public.courses for update using (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));
create policy "courses_admin_delete"   on public.courses for delete using (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));

-- ENROLLMENTS
create policy "enroll_own_select"  on public.enrollments for select using (auth.uid()=student_id or exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));
create policy "enroll_own_insert"  on public.enrollments for insert with check (auth.uid()=student_id);
create policy "enroll_admin_update" on public.enrollments for update using (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));

-- APPLICATIONS
create policy "app_own_select"    on public.applications for select using (auth.uid()=applicant_id or exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));
create policy "app_own_insert"    on public.applications for insert with check (auth.uid()=applicant_id);
create policy "app_admin_update"  on public.applications for update using (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));

-- ASSIGNMENTS
create policy "assign_view_all"   on public.assignments for select using (true);
create policy "assign_admin_all"  on public.assignments for all using (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));

-- SUBMISSIONS
create policy "sub_own_select"    on public.submissions for select using (auth.uid()=student_id or exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));
create policy "sub_own_insert"    on public.submissions for insert with check (auth.uid()=student_id);
create policy "sub_admin_update"  on public.submissions for update using (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));

-- ATTENDANCE
create policy "att_own_select"   on public.attendance for select using (auth.uid()=student_id or exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));
create policy "att_admin_all"    on public.attendance for all using (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));

-- ANNOUNCEMENTS
create policy "ann_view_all"     on public.announcements for select using (true);
create policy "ann_admin_all"    on public.announcements for all using (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));

-- NOTIFICATIONS
create policy "notif_own_select" on public.notifications for select using (auth.uid()=user_id);
create policy "notif_own_update" on public.notifications for update using (auth.uid()=user_id);
create policy "notif_admin_insert" on public.notifications for insert with check (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));

-- SESSIONS
create policy "sess_view_all"    on public.sessions for select using (true);
create policy "sess_admin_all"   on public.sessions for all using (exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));

-- =====================================================================
-- SEED DATA — 6 sample courses
-- =====================================================================
insert into public.courses (title, description, category, level, duration_weeks, contact_hours, image_url) values
('AI and Machine Learning','Master advanced algorithms, neural networks, and predictive modeling.','Data Science AI','Advanced',12,144,'https://lh3.googleusercontent.com/aida-public/AB6AXuDAYKT0q4iG-kqhkM3XCA10_Cc-lE3hbz3KDVxdeO4Jbn5Z-Y_dvv00rbZwejNhk3T44cYXMjWSgaCPhUPTRoXY9ZKMChpSBqsTJOLOkp4SUb7nrLUKhnyK6SILiY9oZ3wTtWkcmmrWLvnLhG2HZCUg333N7VxFnODi4UxMrUV1-R4l4uMX5ymv9Ek1khFB_4c82RtFGm2F5RsqaQ1k12frp7PMqHKrOUnvuoezD6pPis4QgKsp5br3qzV1MAPeqsuRwx8JA9Z4zoA'),
('Cyber Security','Protect infrastructure with advanced offensive and defensive security strategies.','Cyber Defense','Advanced',12,144,'https://lh3.googleusercontent.com/aida-public/AB6AXuDmcafSv7MT1jBFRmGuX8qRdP22TbAqLM3Q3oP_RhEQE_0E6YAeSPAZwXG7S_yXaChK-OMadTVan67lFyDEuDZKBm2vSpGzu2jAqJHWqH_wJstmh5R3WNV6G6D9vzmdoNB5YoaUqtP613qa7lcv8ar2j3xYGyOolq6KzkcbFnrwZuK1HfVmlbwbk1IufJFomQacoejPyRKayjA_X66NGKIfEMcR3DifVFFfz1OFLnGjOaT-4ajuYqwIMP5KkOXjvlc3PFzZJm3Ruy0'),
('Graphics Design / UI-UX','Learn to design intuitive interfaces and visually compelling digital experiences.','Design','Intermediate',12,108,'https://lh3.googleusercontent.com/aida-public/AB6AXuBlL2N9TEqBRFwYOsZAcppUVKHPQXUPTnItqks1C8S8D7biSvh2lgbM0gKDdSQ-oz0verezLEScrV6C1rVCe0GanDp3Kx5saL6ySKmASMMBqzk2JWZHkm6tpNas-iwpy33m5qSxiiGBg38swEiEW23J9z5v1sfRRi1antxwd_ntlEzTaKUUoZqUngoFfExwRqUrUzicU0FAinPTBxBcHfTKiN0PyTER4L5btKsfu0fONgPPcYvZOV8XYxQjHN8bCpJe7LL6ET2SWcA'),
('Full Stack Web Development','Develop end-to-end web applications using modern frameworks and databases.','Web Development','Intermediate',12,108,'https://lh3.googleusercontent.com/aida-public/AB6AXuC5XWXLAIxAg8DPHDUrBbKPJ7WGF8us5BzY94raPYBLmWwm8DmhEKZ3orwWoOEEbTTveGdmPNSrR9Dlk7GQyncvM5kPIwoQs7C5wjQaG5k0X75UISuh_kIUcENmA9mAbGebXT7TxmaCt3NTNvHKVjaEhp6HnHh89Vg_NDZlTm_zMAiezxIhHY8CndCiZdTQVesoOSyjlBfs8mWzMkeeWkpnnePTJ59k3DWxf0Gps2qZPnHp-GcgXf5U9B83Pj_hFOdRi0Ljvig3xWE'),
('Big Data Engineering','Build scalable data pipelines and distributed systems for high-volume data.','Data Engineering','Advanced',12,144,'https://lh3.googleusercontent.com/aida-public/AB6AXuDgcuSUmbRGtIXMfplZMMleuN1U9kFFGQfYL5Ma7Mul_Y-3vP_fqaL_LpVjfjLJeojSdV4v3lhKxDKnXsGaIUT8mKp-3zu3Wx9YrdFwfyE2-_al_hcL6D4zxFp9oGRfs0NhWqvOLhcKYluyB8M2ErMd0p2_9dvoocVl5d-ytdJvwmAvyS155qGGZ3NyuyBfO_ITTOL-osavetaU1uOHulmUorMLbIDpAra8BMCpJ4fQ7n0-qmG5QKjde6kincB5kRtf032psAXrdns'),
('Digital Forensics','Forensic data acquisition, chain of custody, and incident reconstruction techniques.','Cyber Defense','Advanced',12,144,'https://lh3.googleusercontent.com/aida-public/AB6AXuCr8QnEdzK0YEiXaAakW54tmkcVlpcVdWWjRzJSLOD2iPdF48CLhsoakTE3HBXHdhM75bRS8JDXP3IkS-0lNS_FH9EMijOdnlNr4L1nke-8WHAKTRaz7luTo_AhVO43KvizGavZnVe863vYp9dmH5yZ5a2SvBICDJK9duA8X-xewIrAciquNMxXI2R2Lld5ROQy5BfCW5J6aaPNyvUcFnM7p0vzCy1QvpQGun0QEbPqINBMOdVGeOQTSx156AFuATBp3y7ctObZUWA')
on conflict do nothing;

-- =====================================================================
-- STORAGE BUCKET for documents
-- =====================================================================
insert into storage.buckets (id, name, public) values ('documents','documents',false) on conflict do nothing;

create policy "Users upload own docs" on storage.objects for insert with check (bucket_id='documents' and auth.uid()::text=(storage.foldername(name))[1]);
create policy "Users read own docs"   on storage.objects for select using (bucket_id='documents' and auth.uid()::text=(storage.foldername(name))[1]);
create policy "Admins read all docs"  on storage.objects for select using (bucket_id='documents' and exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','instructor')));

-- =====================================================================
-- DONE! Ab Authentication → Sign In/Providers → Email → Confirm email OFF karo
-- Phir website pe signup karo aur Supabase mein apna role 'admin' kar lo
-- =====================================================================
