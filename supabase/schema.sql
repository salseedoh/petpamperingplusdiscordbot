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
  image_filename text,
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
  kind text not null check (kind in ('trivia', 'quiz', 'daily', 'test')),
  guild_id text not null,
  channel_id text not null,
  message_id text,
  owner_discord_user_id text,
  daily_date date,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (guild_id, daily_date)
);

create table if not exists public.daily_question_rotations (
  guild_id text primary key,
  used_question_ids jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
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

create table if not exists public.employee_milestones (
  id uuid primary key default gen_random_uuid(),
  discord_user_id text not null references public.employee_profiles(discord_user_id) on delete cascade,
  kind text not null check (kind in ('correct_answers', 'daily_streak')),
  milestone_value integer not null check (milestone_value > 0),
  achieved_at timestamptz not null default now(),
  unique (discord_user_id, kind, milestone_value)
);

alter table public.question_sessions add column if not exists quiz_run_id uuid references public.quiz_runs(id) on delete cascade;
alter table public.question_sessions add column if not exists message_id text;
alter table public.training_cards add column if not exists sections jsonb not null default '[]'::jsonb;
alter table public.questions add column if not exists image_filename text;
alter table public.question_sessions drop constraint if exists question_sessions_kind_check;
alter table public.question_sessions add constraint question_sessions_kind_check check (kind in ('trivia', 'quiz', 'daily', 'test'));

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
alter table public.daily_question_rotations enable row level security;
alter table public.question_answers enable row level security;
alter table public.employee_profiles enable row level security;
alter table public.quiz_runs enable row level security;
alter table public.employee_milestones enable row level security;

-- This project intentionally does not expose new tables to public client roles.
-- Grant access only to the bot's server-side secret key (the service_role database role).
grant usage on schema public to service_role;
grant select, insert, update, delete on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;

create or replace function public.award_question_answer(
  p_session_id uuid,
  p_discord_user_id text,
  p_display_name text,
  p_selected_option integer
)
returns table (already_answered boolean, is_correct boolean, daily_streak integer)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_kind text;
  v_daily_date date;
  v_correct_option integer;
  v_option_count integer;
  v_is_correct boolean;
  v_points integer;
  v_answer_id uuid;
  v_existing_correct boolean;
  v_streak integer;
begin
  select session.kind, session.daily_date, question.correct_option, jsonb_array_length(question.options)
    into v_kind, v_daily_date, v_correct_option, v_option_count
  from public.question_sessions as session
  join public.questions as question on question.id = session.question_id
  where session.id = p_session_id;
  if not found then raise exception 'Question session was not found.'; end if;
  if v_kind = 'test' then raise exception 'Test questions do not record answers.'; end if;
  if p_selected_option < 0 or p_selected_option >= v_option_count then raise exception 'Selected option is not valid for this question.'; end if;

  v_is_correct := p_selected_option = v_correct_option;
  v_points := case when v_is_correct then case when v_kind = 'daily' then 10 else 1 end else 0 end;
  insert into public.question_answers (session_id, discord_user_id, selected_option, is_correct, points_awarded)
  values (p_session_id, p_discord_user_id, p_selected_option, v_is_correct, v_points)
  on conflict (session_id, discord_user_id) do nothing
  returning id into v_answer_id;
  if v_answer_id is null then
    select answer.is_correct, coalesce(profile.daily_streak, 0)
      into v_existing_correct, v_streak
    from public.question_answers as answer
    left join public.employee_profiles as profile on profile.discord_user_id = p_discord_user_id
    where answer.session_id = p_session_id and answer.discord_user_id = p_discord_user_id;
    return query select true, coalesce(v_existing_correct, false), coalesce(v_streak, 0);
    return;
  end if;

  insert into public.employee_profiles as profile (discord_user_id, display_name, total_points, daily_streak, last_daily_date, updated_at)
  values (p_discord_user_id, p_display_name, v_points, case when v_daily_date is null then 0 when v_is_correct then 1 else 0 end, v_daily_date, now())
  on conflict (discord_user_id) do update set
    display_name = excluded.display_name,
    total_points = profile.total_points + v_points,
    daily_streak = case when v_daily_date is null then profile.daily_streak when v_is_correct and profile.last_daily_date = v_daily_date - 1 then profile.daily_streak + 1 when v_is_correct then 1 else 0 end,
    last_daily_date = case when v_daily_date is null then profile.last_daily_date else v_daily_date end,
    updated_at = now()
  returning profile.daily_streak into v_streak;
  return query select false, v_is_correct, coalesce(v_streak, 0);
end;
$$;

revoke all on function public.award_question_answer(uuid, text, text, integer) from public, anon, authenticated;
grant execute on function public.award_question_answer(uuid, text, text, integer) to service_role;

create index if not exists question_answers_correct_user_idx on public.question_answers (discord_user_id) where is_correct;
create index if not exists question_answers_answered_at_idx on public.question_answers (answered_at);
create index if not exists question_sessions_daily_history_idx on public.question_sessions (guild_id, kind, question_id) where kind = 'daily';

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
