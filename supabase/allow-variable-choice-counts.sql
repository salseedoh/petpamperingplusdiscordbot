-- Run this once in Supabase Dashboard > SQL Editor.
-- It allows True/False (2 choices), four-choice, and five-choice questions.

alter table public.questions drop constraint if exists questions_options_check;
alter table public.questions drop constraint if exists questions_correct_option_check;
alter table public.questions drop constraint if exists questions_options_choice_count_check;
alter table public.questions drop constraint if exists questions_correct_option_range_check;
alter table public.questions add constraint questions_options_choice_count_check check (jsonb_typeof(options) = 'array' and jsonb_array_length(options) in (2, 4, 5));
alter table public.questions add constraint questions_correct_option_range_check check (correct_option >= 0 and correct_option < jsonb_array_length(options));

alter table public.question_answers drop constraint if exists question_answers_selected_option_check;
alter table public.question_answers add constraint question_answers_selected_option_check check (selected_option between 0 and 4);
