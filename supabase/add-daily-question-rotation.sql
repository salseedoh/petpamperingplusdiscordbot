-- Run this entire file once in Supabase Dashboard > SQL Editor.
-- Stores the current daily-question rotation for the bot's server-side use.

create table if not exists public.daily_question_rotations (
  guild_id text primary key,
  used_question_ids jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.daily_question_rotations enable row level security;
grant select, insert, update, delete on public.daily_question_rotations to service_role;

-- Used only when the bot first establishes a rotation from earlier daily posts.
create index if not exists question_sessions_daily_history_idx
  on public.question_sessions (guild_id, kind, question_id)
  where kind = 'daily';
