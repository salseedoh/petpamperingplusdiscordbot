-- Run this entire file once in Supabase Dashboard > SQL Editor.
-- It makes a submitted answer and its score/streak update one atomic operation,
-- so a temporary network failure cannot award duplicate points.

create or replace function public.award_question_answer(
  p_session_id uuid,
  p_discord_user_id text,
  p_display_name text,
  p_selected_option integer
)
returns table (
  already_answered boolean,
  is_correct boolean,
  daily_streak integer
)
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

  if not found then
    raise exception 'Question session was not found.';
  end if;
  if v_kind = 'test' then
    raise exception 'Test questions do not record answers.';
  end if;
  if p_selected_option < 0 or p_selected_option >= v_option_count then
    raise exception 'Selected option is not valid for this question.';
  end if;

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

  insert into public.employee_profiles as profile (
    discord_user_id, display_name, total_points, daily_streak, last_daily_date, updated_at
  ) values (
    p_discord_user_id,
    p_display_name,
    v_points,
    case when v_daily_date is null then 0 when v_is_correct then 1 else 0 end,
    v_daily_date,
    now()
  )
  on conflict (discord_user_id) do update set
    display_name = excluded.display_name,
    total_points = profile.total_points + v_points,
    daily_streak = case
      when v_daily_date is null then profile.daily_streak
      when v_is_correct and profile.last_daily_date = v_daily_date - 1 then profile.daily_streak + 1
      when v_is_correct then 1
      else 0
    end,
    last_daily_date = case when v_daily_date is null then profile.last_daily_date else v_daily_date end,
    updated_at = now()
  returning profile.daily_streak into v_streak;

  return query select false, v_is_correct, coalesce(v_streak, 0);
end;
$$;

revoke all on function public.award_question_answer(uuid, text, text, integer) from public, anon, authenticated;
grant execute on function public.award_question_answer(uuid, text, text, integer) to service_role;
