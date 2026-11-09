-- =====================================================
-- RAKESHH PHYSICS SCHOLARSHIP PORTAL
-- DATABASE SCHEMA VERSION 2
-- Existing website tables remain untouched.
-- =====================================================

create extension if not exists pgcrypto;

-- 1. ADMIN ROLES
create table if not exists public.scholarship_admin_roles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    admin_role text not null check (
        admin_role in ('primary_admin', 'secondary_admin')
    ),
    created_at timestamptz not null default now()
);

-- Rakesh Sir: Primary Admin
insert into public.scholarship_admin_roles (user_id, admin_role)
values (
    '248b079c-bcbf-4ac8-aca0-ab915382828d',
    'primary_admin'
)
on conflict (user_id) do update
set admin_role = excluded.admin_role;

-- Abhinav: Secondary Admin
insert into public.scholarship_admin_roles (user_id, admin_role)
values (
    '3ccfcc28-c94f-41de-98c3-e9d892b49998',
    'secondary_admin'
)
on conflict (user_id) do update
set admin_role = excluded.admin_role;

-- Admin verification function
create or replace function public.is_scholarship_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.scholarship_admin_roles
        where user_id = (select auth.uid())
    );
$$;

-- 2. REGISTRATION ID SEQUENCE
create sequence if not exists public.scholarship_registration_seq
start 1001;

create or replace function public.generate_scholarship_registration_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.registration_id is null then
        new.registration_id :=
            'RP' || to_char(current_date, 'YYYY') ||
            lpad(
                nextval('public.scholarship_registration_seq')::text,
                5,
                '0'
            );
    end if;
    return new;
end;
$$;

-- 3. STUDENTS
create table if not exists public.scholarship_students (
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
    stream text,
    board text,
    school text,
    district text,
    state text default 'Bihar',
    created_at timestamptz not null default now(),
    constraint scholarship_stream_check check (
        (category = '10th' and stream is null)
        or
        (category in ('11th', '12th') and stream in ('PCB', 'PCM'))
    )
);

drop trigger if exists scholarship_student_registration_id
on public.scholarship_students;

create trigger scholarship_student_registration_id
before insert on public.scholarship_students
for each row
execute function public.generate_scholarship_registration_id();

-- 4. EXAM PAPERS
create table if not exists public.scholarship_exam_papers (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    category text not null check (
        category in ('10th', '11th', '12th')
    ),
    stream text,
    duration_minutes integer not null default 37,
    total_questions integer not null default 50,
    is_active boolean not null default false,
    created_at timestamptz not null default now()
);

-- 5. QUESTIONS
create table if not exists public.scholarship_questions (
    id uuid primary key default gen_random_uuid(),
    exam_paper_id uuid not null
        references public.scholarship_exam_papers(id) on delete cascade,
    question_text text not null,
    options jsonb not null,
    correct_option text not null,
    explanation text,
    difficulty text check (difficulty in ('Easy', 'Hard')),
    subject text,
    marks_correct integer not null default 4,
    marks_wrong integer not null default -1,
    question_order integer not null,
    created_at timestamptz not null default now(),
    unique(exam_paper_id, question_order)
);

-- 6. EXAM ATTEMPTS
create table if not exists public.scholarship_exam_attempts (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null
        references public.scholarship_students(id),
    exam_paper_id uuid not null
        references public.scholarship_exam_papers(id),
    started_at timestamptz not null default now(),
    submitted_at timestamptz,
    status text not null default 'in_progress'
        check (status in ('in_progress', 'submitted', 'evaluated')),
    score numeric(8,2),
    correct_count integer default 0,
    wrong_count integer default 0,
    unanswered_count integer default 0
);

-- 7. STUDENT RESPONSES
create table if not exists public.scholarship_student_responses (
    id uuid primary key default gen_random_uuid(),
    attempt_id uuid not null
        references public.scholarship_exam_attempts(id) on delete cascade,
    question_id uuid not null
        references public.scholarship_questions(id),
    selected_option text,
    is_correct boolean,
    marks_awarded numeric(6,2) default 0,
    answered_at timestamptz not null default now(),
    unique(attempt_id, question_id)
);

-- 8. RESULTS
create table if not exists public.scholarship_results (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null
        references public.scholarship_students(id),
    exam_paper_id uuid not null
        references public.scholarship_exam_papers(id),
    attempt_id uuid references public.scholarship_exam_attempts(id),
    total_marks numeric(8,2),
    rank integer,
    remarks text,
    is_published boolean not null default false,
    published_at timestamptz,
    created_at timestamptz not null default now(),
    unique(student_id, exam_paper_id)
);

-- 9. ENABLE ROW LEVEL SECURITY
alter table public.scholarship_admin_roles enable row level security;
alter table public.scholarship_students enable row level security;
alter table public.scholarship_exam_papers enable row level security;
alter table public.scholarship_questions enable row level security;
alter table public.scholarship_exam_attempts enable row level security;
alter table public.scholarship_student_responses enable row level security;
alter table public.scholarship_results enable row level security;

-- 10. ADMIN POLICIES
create policy "Scholarship admins manage admin roles"
on public.scholarship_admin_roles
for all to authenticated
using (public.is_scholarship_admin())
with check (public.is_scholarship_admin());

create policy "Scholarship admins manage students"
on public.scholarship_students
for all to authenticated
using (public.is_scholarship_admin())
with check (public.is_scholarship_admin());

create policy "Scholarship admins manage exam papers"
on public.scholarship_exam_papers
for all to authenticated
using (public.is_scholarship_admin())
with check (public.is_scholarship_admin());

create policy "Scholarship admins manage questions"
on public.scholarship_questions
for all to authenticated
using (public.is_scholarship_admin())
with check (public.is_scholarship_admin());

create policy "Scholarship admins manage attempts"
on public.scholarship_exam_attempts
for all to authenticated
using (public.is_scholarship_admin())
with check (public.is_scholarship_admin());

create policy "Scholarship admins manage responses"
on public.scholarship_student_responses
for all to authenticated
using (public.is_scholarship_admin())
with check (public.is_scholarship_admin());

create policy "Scholarship admins manage results"
on public.scholarship_results
for all to authenticated
using (public.is_scholarship_admin())
with check (public.is_scholarship_admin());

-- 11. PUBLIC REGISTRATION INSERT ONLY
create policy "Public scholarship registration"
on public.scholarship_students
for insert to anon, authenticated
with check (
    length(trim(student_name)) > 0
    and length(trim(father_name)) > 0
    and length(trim(mobile)) >= 10
);

-- =====================================================
-- END OF SCHOLARSHIP PORTAL SCHEMA
-- =====================================================
-- ==========================================
-- PRIMARY ADMIN SECURITY
-- Only Rakesh Sir can manage admin roles
-- ==========================================

create or replace function public.is_scholarship_primary_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.scholarship_admin_roles
        where user_id = (select auth.uid())
        and admin_role = 'primary_admin'
    );
$$;

drop policy if exists "Scholarship admins manage admin roles"
on public.scholarship_admin_roles;

create policy "Primary admin manages admin roles"
on public.scholarship_admin_roles
for all
to authenticated
using (public.is_scholarship_primary_admin())
with check (public.is_scholarship_primary_admin());
