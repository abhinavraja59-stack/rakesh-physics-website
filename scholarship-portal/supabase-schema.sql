-- ==========================================
-- RAKESHH PHYSICS SCHOLARSHIP PORTAL
-- DATABASE SCHEMA - VERSION 1
-- ==========================================

create extension if not exists pgcrypto;

-- 1. Unique Registration ID Sequence
create sequence if not exists public.student_reg_seq start 1001;

create or replace function public.generate_registration_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.registration_id is null then
        new.registration_id :=
            'RP' || to_char(current_date, 'YYYY') ||
            lpad(nextval('public.student_reg_seq')::text, 5, '0');
    end if;
    return new;
end;
$$;

-- 2. Students
create table if not exists public.students (
    id uuid primary key default gen_random_uuid(),
    registration_id text unique,
    student_name text not null,
    father_name text not null,
    mobile text not null,
    whatsapp text,
    date_of_birth date,
    gender text,
    category text not null check (
        category in ('10th', '11th', '12th')
    ),
    stream text check (
        stream in ('PCB', 'PCM') or stream is null
    ),
    board text,
    school text,
    district text,
    state text default 'Bihar',
    created_at timestamptz default now()
);

drop trigger if exists set_student_registration_id
on public.students;

create trigger set_student_registration_id
before insert on public.students
for each row execute function public.generate_registration_id();

-- 3. Admin Roles
create table if not exists public.user_roles (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    role text not null default 'admin',
    unique(user_id, role)
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.user_roles
        where user_id = (select auth.uid())
        and role = 'admin'
    );
$$;

-- 4. Exam Papers
create table if not exists public.exam_papers (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    category text not null,
    stream text,
    duration_minutes integer not null default 37,
    total_questions integer not null default 50,
    is_active boolean default false,
    created_at timestamptz default now()
);

-- 5. Questions
create table if not exists public.questions (
    id uuid primary key default gen_random_uuid(),
    exam_paper_id uuid not null references public.exam_papers(id) on delete cascade,
    question_text text not null,
    options jsonb not null,
    correct_option text not null,
    explanation text,
    difficulty text check (difficulty in ('Easy', 'Hard')),
    subject text,
    marks_correct integer default 4,
    marks_wrong integer default -1,
    question_order integer not null,
    created_at timestamptz default now(),
    unique(exam_paper_id, question_order)
);

-- 6. Exam Attempts
create table if not exists public.exam_attempts (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null references public.students(id),
    exam_paper_id uuid not null references public.exam_papers(id),
    started_at timestamptz default now(),
    submitted_at timestamptz,
    status text default 'in_progress'
        check (status in ('in_progress', 'submitted', 'evaluated')),
    score numeric(8,2),
    correct_count integer default 0,
    wrong_count integer default 0,
    unanswered_count integer default 0
);

-- 7. Student Responses
create table if not exists public.student_responses (
    id uuid primary key default gen_random_uuid(),
    attempt_id uuid not null references public.exam_attempts(id) on delete cascade,
    question_id uuid not null references public.questions(id),
    selected_option text,
    is_correct boolean,
    marks_awarded numeric(6,2) default 0,
    answered_at timestamptz default now(),
    unique(attempt_id, question_id)
);

-- 8. Published Results
create table if not exists public.results (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null references public.students(id),
    exam_paper_id uuid not null references public.exam_papers(id),
    attempt_id uuid references public.exam_attempts(id),
    total_marks numeric(8,2),
    rank integer,
    remarks text,
    is_published boolean default false,
    published_at timestamptz,
    created_at timestamptz default now(),
    unique(student_id, exam_paper_id)
);

-- 9. Enable Row Level Security
alter table public.students enable row level security;
alter table public.user_roles enable row level security;
alter table public.exam_papers enable row level security;
alter table public.questions enable row level security;
alter table public.exam_attempts enable row level security;
alter table public.student_responses enable row level security;
alter table public.results enable row level security;

-- 10. Student Registration: public insert only
create policy "Public student registration"
on public.students
for insert
to anon, authenticated
with check (
    length(trim(student_name)) > 0
    and length(trim(father_name)) > 0
    and length(trim(mobile)) >= 10
    and (
        (category = '10th' and stream is null)
        or
        (category in ('11th', '12th') and stream in ('PCB', 'PCM'))
    )
);

-- 11. Admin-only access policies
create policy "Admins manage students"
on public.students
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Admins manage roles"
on public.user_roles
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Admins manage exam papers"
on public.exam_papers
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Admins manage questions"
on public.questions
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Admins manage attempts"
on public.exam_attempts
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Admins manage responses"
on public.student_responses
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Admins manage results"
on public.results
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

-- ==========================================
-- END OF DATABASE SCHEMA
-- ==========================================
