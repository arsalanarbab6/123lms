# CyberEdge Academy — Setup Guide
## Pehle yeh padho, phir shuru karo

---

## STEP 1 — Supabase database setup

1. Apna Supabase project kholein: https://supabase.com/dashboard
2. Left sidebar mein **"SQL Editor"** pe click karein
3. **"New query"** pe click karein
4. Is folder mein `database_schema.sql` file hai — use Notepad mein kholein, poora content **Ctrl+A** se select karein, copy karein
5. Supabase SQL Editor mein paste karein
6. **"Run"** button dabayein (ya Ctrl+Enter)
7. "Success" message aayega — iska matlab database ready hai (tables + 6 sample courses)

---

## STEP 2 — Email confirmation OFF karein (important for testing)

1. Supabase dashboard mein **Authentication** pe click karein
2. Upar **"Sign In / Providers"** tab pe jayein
3. **Email** pe click karein
4. **"Confirm email"** toggle ko **OFF** kar dein
5. Save karein

> Ab jab koi signup karega, seedha login ho jayega — email pe link click karne ki zaroorat nahi.

---

## STEP 3 — Website locally chalayein

**Command Prompt** mein:
```
cd Desktop\cyberedge-site
python -m http.server 8000
```

Browser mein kholein:
```
http://localhost:8000/public/index.html
```

---

## STEP 4 — Khud ko Admin banayein

1. Pehle website pe **signup** karein (normal student account)
2. Supabase dashboard mein **Table Editor** pe jayein
3. **profiles** table kholein
4. Apni row mein **role** column ko `student` se `admin` mein badlein
5. Wapas website pe **login** karein → aap seedha Admin Dashboard pe jayenge

---

## Pages aur unke URLs

| Page | URL |
|------|-----|
| Home | /public/index.html |
| All Courses | /public/courses.html |
| Login | /public/login.html |
| Sign Up | /public/signup.html |
| Forgot Password | /public/forgot-password.html |
| Student Dashboard | /student/dashboard.html |
| Admin Dashboard | /admin/dashboard.html |
| Admin — Courses (Add/Edit/Delete) | /admin/courses.html |
| Admin — Users | /admin/users.html |

---

## Folder structure

```
cyberedge-site/
├── database_schema.sql      ← Supabase SQL Editor mein run karein
├── assets/
│   ├── js/app.js            ← Supabase connection (shared)
│   └── css/style.css        ← Shared styles
├── public/                  ← Bina login ke dekhne wale pages
│   ├── index.html
│   ├── courses.html
│   ├── login.html
│   ├── signup.html
│   ├── forgot-password.html
│   └── reset-password.html
├── student/                 ← Student login ke baad
│   └── dashboard.html
├── admin/                   ← Admin login ke baad
│   ├── dashboard.html
│   ├── courses.html         ← Add/Edit/Delete courses
│   └── users.html
```

---

## Is hafte jo banega (next sessions)

- [ ] About, Eligibility, FAQs, How It Works, Contact pages
- [ ] Student — My Courses, Assignments, Attendance, Quizzes, Results, Profile
- [ ] Admin — Applications, Enrollments, Attendance management, Announcements
- [ ] Instructor Panel — Dashboard, My Courses, Students list, Grading

---

## Supabase credentials (aap ke liye)
- **URL:** https://bxldognxqykyvqtqxiga.supabase.co
- **Publishable Key:** sb_publishable_xfaNK_mPjXOtV4owY0qIhg_a8L3J3t8
