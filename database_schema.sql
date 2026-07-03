-- =====================================================================
-- CyberEdge Academy — Database Schema for Supabase
-- Run this ENTIRE file in: Supabase Dashboard -> SQL Editor -> New Query
-- =====================================================================

-- 1. PROFILES TABLE (extends Supabase auth.users)
-- Every signed-up user automatically gets a row here via a trigger.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  phone text,
  role text not null default 'student' check (role in ('student', 'instructor', 'admin')),
  avatar_url text,
  created_at timestamp with time zone default now()
);

-- Auto-create a profile row whenever someone signs up
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

-- 2. COURSES TABLE
create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  category text,                 -- e.g. 'Cyber Defense', 'AI & ML'
  level text default 'Intermediate', -- Intermediate / Advanced
  duration_weeks int default 12,
  contact_hours int default 144,
  image_url text,
  is_published boolean default true,
  created_by uuid references public.profiles(id),
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 3. ENROLLMENTS (student <-> course)
create table if not exists public.enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.profiles(id) on delete cascade,
  course_id uuid references public.courses(id) on delete cascade,
  progress_percent int default 0,
  status text default 'active' check (status in ('active', 'completed', 'dropped')),
  enrolled_at timestamp with time zone default now(),
  unique (student_id, course_id)
);

-- 4. APPLICATIONS (admission applications before enrollment)
create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  applicant_id uuid references public.profiles(id) on delete cascade,
  course_id uuid references public.courses(id),
  status text default 'pending' check (status in ('pending', 'screening', 'shortlisted', 'rejected', 'accepted')),
  score int,
  submitted_at timestamp with time zone default now()
);

-- 5. ASSIGNMENTS
create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  course_id uuid references public.courses(id) on delete cascade,
  title text not null,
  description text,
  due_date timestamp with time zone,
  max_points int default 100,
  created_at timestamp with time zone default now()
);

-- 6. ASSIGNMENT SUBMISSIONS
create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid references public.assignments(id) on delete cascade,
  student_id uuid references public.profiles(id) on delete cascade,
  file_url text,
  submitted_at timestamp with time zone default now(),
  grade int,
  feedback text
);

-- 7. ATTENDANCE
create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.profiles(id) on delete cascade,
  course_id uuid references public.courses(id) on delete cascade,
  session_date date not null,
  status text default 'present' check (status in ('present', 'absent', 'late')),
  marked_at timestamp with time zone default now()
);

-- 8. NOTIFICATIONS
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  message text,
  category text default 'system',
  is_read boolean default false,
  created_at timestamp with time zone default now()
);

-- =====================================================================
-- ROW LEVEL SECURITY (RLS) — keeps data safe by default
-- =====================================================================

alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.enrollments enable row level security;
alter table public.applications enable row level security;
alter table public.assignments enable row level security;
alter table public.submissions enable row level security;
alter table public.attendance enable row level security;
alter table public.notifications enable row level security;

-- PROFILES: users can read/update only their own profile; everyone can read basic profile info
create policy "profiles_select_all" on public.profiles for select using (true);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- COURSES: anyone (even logged out) can view published courses
create policy "courses_select_published" on public.courses for select using (is_published = true);
-- admins/instructors can insert/update/delete their courses
create policy "courses_insert_admin" on public.courses for insert
  with check (exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor')));
create policy "courses_update_admin" on public.courses for update
  using (exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor')));
create policy "courses_delete_admin" on public.courses for delete
  using (exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor')));

-- ENROLLMENTS: students see their own; admins/instructors see all
create policy "enrollments_select_own" on public.enrollments for select
  using (auth.uid() = student_id or exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor')));
create policy "enrollments_insert_own" on public.enrollments for insert
  with check (auth.uid() = student_id);

-- APPLICATIONS: applicants see their own; admins see all
create policy "applications_select_own" on public.applications for select
  using (auth.uid() = applicant_id or exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor')));
create policy "applications_insert_own" on public.applications for insert
  with check (auth.uid() = applicant_id);
create policy "applications_update_admin" on public.applications for update
  using (exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor')));

-- ASSIGNMENTS: enrolled students + instructors/admins can view; only instructors/admins can manage
create policy "assignments_select_all" on public.assignments for select using (true);
create policy "assignments_manage_admin" on public.assignments for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor')));

-- SUBMISSIONS: students manage their own; instructors/admins can view & grade all
create policy "submissions_select_own" on public.submissions for select
  using (auth.uid() = student_id or exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor')));
create policy "submissions_insert_own" on public.submissions for insert
  with check (auth.uid() = student_id);
create policy "submissions_update_admin" on public.submissions for update
  using (exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor')));

-- ATTENDANCE: students view their own; instructors/admins manage all
create policy "attendance_select_own" on public.attendance for select
  using (auth.uid() = student_id or exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor')));
create policy "attendance_manage_admin" on public.attendance for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','instructor')));

-- NOTIFICATIONS: users see only their own
create policy "notifications_select_own" on public.notifications for select using (auth.uid() = user_id);
create policy "notifications_update_own" on public.notifications for update using (auth.uid() = user_id);

-- =====================================================================
-- SEED DATA (sample courses so the site isn't empty on first load)
-- =====================================================================
insert into public.courses (title, description, category, level, duration_weeks, contact_hours, image_url)
values
  ('AI and Machine Learning', 'Master advanced algorithms, neural networks, and predictive modeling for enterprise intelligence.', 'Data Science AI', 'Advanced', 12, 144, 'https://lh3.googleusercontent.com/aida-public/AB6AXuDAYKT0q4iG-kqhkM3XCA10_Cc-lE3hbz3KDVxdeO4Jbn5Z-Y_dvv00rbZwejNhk3T44cYXMjWSgaCPhUPTRoXY9ZKMChpSBqsTJOLOkp4SUb7nrLUKhnyK6SILiY9oZ3wTtWkcmmrWLvnLhG2HZCUg333N7VxFnODi4UxMrUV1-R4l4uMX5ymv9Ek1khFB_4c82RtFGm2F5RsqaQ1k12frp7PMqHKrOUnvuoezD6pPis4QgKsp5br3qzV1MAPeqsuRwx8JA9Z4zoA'),
  ('Cyber Security', 'Protect infrastructure with advanced offensive and defensive security strategies and tools.', 'Cyber Defense', 'Advanced', 12, 144, 'https://lh3.googleusercontent.com/aida-public/AB6AXuDmcafSv7MT1jBFRmGuX8qRdP22TbAqLM3Q3oP_RhEQE_0E6YAeSPAZwXG7S_yXaChK-OMadTVan67lFyDEuDZKBm2vSpGzu2jAqJHWqH_wJstmh5R3WNV6G6D9vzmdoNB5YoaUqtP613qa7lcv8ar2j3xYGyOolq6KzkcbFnrwZuK1HfVmlbwbk1IufJFomQacoejPyRKayjA_X66NGKIfEMcR3DifVFFfz1OFLnGjOaT-4ajuYqwIMP5KkOXjvlc3PFzZJm3Ruy0'),
  ('Graphics Design / UI-UX', 'Learn to design intuitive interfaces and visually compelling digital experiences for modern products.', 'Design', 'Intermediate', 12, 108, 'https://lh3.googleusercontent.com/aida-public/AB6AXuBlL2N9TEqBRFwYOsZAcppUVKHPQXUPTnItqks1C8S8D7biSvh2lgbM0gKDdSQ-oz0verezLEScrV6C1rVCe0GanDp3Kx5saL6ySKmASMMBqzk2JWZHkm6tpNas-iwpy33m5qSxiiGBg38swEiEW23J9z5v1sfRRi1antxwd_ntlEzTaKUUoZqUngoFfExwRqUrUzicU0FAinPTBxBcHfTKiN0PyTER4L5btKsfu0fONgPPcYvZOV8XYxQjHN8bCpJe7LL6ET2SWcA'),
  ('Full Stack Web Development', 'Develop end-to-end web applications using modern frameworks, databases, and deployment pipelines.', 'Web Development', 'Intermediate', 12, 108, 'https://lh3.googleusercontent.com/aida-public/AB6AXuC5XWXLAIxAg8DPHDUrBbKPJ7WGF8us5BzY94raPYBLmWwm8DmhEKZ3orwWoOEEbTTveGdmPNSrR9Dlk7GQyncvM5kPIwoQs7C5wjQaG5k0X75UISuh_kIUcENmA9mAbGebXT7TxmaCt3NTNvHKVjaEhp6HnHh89Vg_NDZlTm_zMAiezxIhHY8CndCiZdTQVesoOSyjlBfs8mWzMkeeWkpnnePTJ59k3DWxf0Gps2qZPnHp-GcgXf5U9B83Pj_hFOdRi0Ljvig3xWE'),
  ('Big Data Engineering', 'Build scalable data pipelines, distributed systems, and architect high-volume data warehouses.', 'Data Engineering', 'Advanced', 12, 144, 'https://lh3.googleusercontent.com/aida-public/AB6AXuDgcuSUmbRGtIXMfplZMMleuN1U9kFFGQfYL5Ma7Mul_Y-3vP_fqaL_LpVjfjLJeojSdV4v3lhKxDKnXsGaIUT8mKp-3zu3Wx9YrdFwfyE2-_al_hcL6D4zxFp9oGRfs0NhWqvOLhcKYluyB8M2ErMd0p2_xdvoocVl5d-ytdJvwmAvyS155qGGZ3NyuyBfO_ITTOL-osavetaU1uOHulmUorMLbIDpAra8BMCpJ4fQ7n0-qmG5QKjde6kincB5kRtf032psAXrdns'),
  ('Digital Forensics', 'Standard operating procedures for forensic data acquisition, chain of custody, and incident reconstruction.', 'Cyber Defense', 'Advanced', 12, 144, 'https://lh3.googleusercontent.com/aida-public/AB6AXuCr8QnEdzK0YEiXaAakW54tmkcVlpcVdWWjRzJSLOD2iPdF48CLhsoakTE3HBXHdhM75bRS8JDXP3IkS-0lNS_FH9EMijOdnlNr4L1nke-8WHAKTRaz7luTo_AhVO43KvizGavZnVe863vYp9dmH5yZ5a2SvBICDJK9duA8X-xewIrAciquNMxXI2R2Lld5ROQy5BfCW5J6aaPNyvUcFnM7p0vzCy1QvpQGun0QEbPqINBMOdVGeOQTSx156AFuATBp3y7ctObZUWA')
on conflict do nothing;

-- =====================================================================
-- DONE. After running this:
-- 1. Go to Authentication -> Providers -> make sure "Email" is enabled.
-- 2. (Optional, for local testing) Authentication -> Settings -> turn OFF
--    "Confirm email" so signup logs you straight in without email verification.
-- =====================================================================
