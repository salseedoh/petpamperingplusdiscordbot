-- Run this entire file once in Supabase Dashboard > SQL Editor.
-- Changes practice-question scoring to 1 point, preserves daily-question scoring
-- at 10 points, and adds private milestone tracking.

begin;

create table if not exists public.employee_milestones (
  id uuid primary key default gen_random_uuid(),
  discord_user_id text not null references public.employee_profiles(discord_user_id) on delete cascade,
  kind text not null check (kind in ('correct_answers', 'daily_streak')),
  milestone_value integer not null check (milestone_value > 0),
  achieved_at timestamptz not null default now(),
  unique (discord_user_id, kind, milestone_value)
);

alter table public.employee_milestones enable row level security;
grant select, insert, update, delete on public.employee_milestones to service_role;

create index if not exists question_answers_correct_user_idx
  on public.question_answers (discord_user_id)
  where is_correct;
create index if not exists question_answers_answered_at_idx
  on public.question_answers (answered_at);

-- Recalculate historical points under the new rules so existing totals and
-- the current-month leaderboard remain internally consistent.
update public.question_answers as answer
set points_awarded = case
  when answer.is_correct and session.kind = 'daily' then 10
  when answer.is_correct then 1
  else 0
end
from public.question_sessions as session
where session.id = answer.session_id;

update public.employee_profiles as profile
set total_points = coalesce((
  select sum(answer.points_awarded)
  from public.question_answers as answer
  where answer.discord_user_id = profile.discord_user_id
), 0),
updated_at = now();

-- Record milestones that employees already reached before this feature was
-- introduced. They are stored silently, so the next private celebration is
-- for a newly reached milestone rather than an old one.
insert into public.employee_milestones (discord_user_id, kind, milestone_value)
select counts.discord_user_id, 'correct_answers', milestone.value
from (
  select discord_user_id, count(*)::integer as correct_answers
  from public.question_answers
  where is_correct
  group by discord_user_id
) as counts
cross join lateral generate_series(25, (floor(counts.correct_answers / 25.0)::integer) * 25, 25) as milestone(value)
on conflict (discord_user_id, kind, milestone_value) do nothing;

insert into public.employee_milestones (discord_user_id, kind, milestone_value)
select profile.discord_user_id, 'daily_streak', milestone.value
from public.employee_profiles as profile
cross join lateral generate_series(7, (floor(profile.daily_streak / 7.0)::integer) * 7, 7) as milestone(value)
where profile.daily_streak >= 7
on conflict (discord_user_id, kind, milestone_value) do nothing;

commit;
