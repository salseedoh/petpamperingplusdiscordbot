-- Run this entire file in Supabase Dashboard > SQL Editor.
-- The bot uses a server-only secret key; these tables are not exposed to public clients.

create extension if not exists pgcrypto;

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  prompt text not null,
  options jsonb not null constraint questions_options_choice_count_check check (jsonb_typeof(options) = 'array' and jsonb_array_length(options) in (2, 4, 5)),
  correct_option smallint not null constraint questions_correct_option_range_check check (correct_option >= 0 and correct_option < jsonb_array_length(options)),
  explanation text not null,
  topic text,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.training_cards (
  id uuid primary key default gen_random_uuid(),
  topic text not null,
  title text not null,
  warning_signs text[] not null default '{}',
  first_steps text[] not null default '{}',
  body text,
  sections jsonb not null default '[]'::jsonb,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.question_sessions (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id),
  kind text not null check (kind in ('trivia', 'quiz', 'daily')),
  guild_id text not null,
  channel_id text not null,
  message_id text,
  owner_discord_user_id text,
  daily_date date,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (guild_id, daily_date)
);

create table if not exists public.question_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.question_sessions(id) on delete cascade,
  discord_user_id text not null,
  selected_option smallint not null check (selected_option between 0 and 4),
  is_correct boolean not null,
  points_awarded integer not null default 0 check (points_awarded >= 0),
  answered_at timestamptz not null default now(),
  unique (session_id, discord_user_id)
);

create table if not exists public.employee_profiles (
  discord_user_id text primary key,
  display_name text not null,
  total_points integer not null default 0 check (total_points >= 0),
  daily_streak integer not null default 0 check (daily_streak >= 0),
  last_daily_date date,
  updated_at timestamptz not null default now()
);

create table if not exists public.quiz_runs (
  id uuid primary key default gen_random_uuid(),
  discord_user_id text not null,
  guild_id text not null,
  question_ids jsonb not null,
  current_index integer not null default 0,
  correct_count integer not null default 0,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.question_sessions add column if not exists quiz_run_id uuid references public.quiz_runs(id) on delete cascade;
alter table public.question_sessions add column if not exists message_id text;
alter table public.training_cards add column if not exists sections jsonb not null default '[]'::jsonb;

-- Supports True/False (2 choices), standard four-choice, and five-choice questions.
-- These statements also update databases created before variable choice counts were supported.
alter table public.questions drop constraint if exists questions_options_check;
alter table public.questions drop constraint if exists questions_correct_option_check;
alter table public.questions drop constraint if exists questions_options_choice_count_check;
alter table public.questions drop constraint if exists questions_correct_option_range_check;
alter table public.questions add constraint questions_options_choice_count_check check (jsonb_typeof(options) = 'array' and jsonb_array_length(options) in (2, 4, 5));
alter table public.questions add constraint questions_correct_option_range_check check (correct_option >= 0 and correct_option < jsonb_array_length(options));
alter table public.question_answers drop constraint if exists question_answers_selected_option_check;
alter table public.question_answers add constraint question_answers_selected_option_check check (selected_option between 0 and 4);

alter table public.questions enable row level security;
alter table public.training_cards enable row level security;
alter table public.question_sessions enable row level security;
alter table public.question_answers enable row level security;
alter table public.employee_profiles enable row level security;
alter table public.quiz_runs enable row level security;

-- This project intentionally does not expose new tables to public client roles.
-- Grant access only to the bot's server-side secret key (the service_role database role).
grant usage on schema public to service_role;
grant select, insert, update, delete on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;

insert into public.questions (prompt, options, correct_option, explanation, topic)
select * from (values
  ('Which planet is known as the Red Planet?', '["Earth", "Mars", "Jupiter", "Venus"]'::jsonb, 1::smallint, 'Mars appears reddish because of iron-rich minerals in its soil.', 'Placeholder'),
  ('What is the capital of Canada?', '["Toronto", "Vancouver", "Ottawa", "Montreal"]'::jsonb, 2::smallint, 'Ottawa is the capital city of Canada.', 'Placeholder'),
  ('Which ocean is the largest?', '["Atlantic", "Indian", "Arctic", "Pacific"]'::jsonb, 3::smallint, 'The Pacific Ocean is the largest and deepest ocean on Earth.', 'Placeholder')
) as seed(prompt, options, correct_option, explanation, topic)
where not exists (select 1 from public.questions);

insert into public.training_cards (topic, title, warning_signs, first_steps, body)
select * from (values
  ('Placeholder', 'Practice Observation', array['Notice the facts', 'Stay calm', 'Ask for help when needed'], array['Pause', 'Review the information', 'Choose the safest next step'], 'This is a placeholder training card. Replace it with approved pet first-aid guidance.'),
  ('Placeholder', 'Communication Basics', array['Unclear information', 'Missing details'], array['Confirm the situation', 'Record key facts', 'Escalate appropriately'], 'This is a placeholder training card. Replace it with approved pet first-aid guidance.')
) as seed(topic, title, warning_signs, first_steps, body)
where not exists (select 1 from public.training_cards);
