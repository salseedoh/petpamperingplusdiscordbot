-- Run this entire file once in Supabase Dashboard > SQL Editor.
-- Allows administrator-only test sessions that do not create answers or award points.

begin;

alter table public.question_sessions drop constraint if exists question_sessions_kind_check;
alter table public.question_sessions add constraint question_sessions_kind_check
  check (kind in ('trivia', 'quiz', 'daily', 'test'));

commit;
