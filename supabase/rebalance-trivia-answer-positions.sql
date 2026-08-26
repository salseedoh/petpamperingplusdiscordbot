-- Run this in Supabase Dashboard > SQL Editor.
-- Repositions answer choices for 17 existing multiple-choice questions.
-- The correct answer text is preserved; only its displayed letter changes.
-- True/False questions are not changed.

begin;

create temporary table answer_position_updates (
  id uuid primary key,
  expected_correct_option smallint not null,
  new_correct_option smallint not null,
  option_count smallint not null
) on commit drop;

insert into answer_position_updates (id, expected_correct_option, new_correct_option, option_count)
values
  -- Four-choice questions: move 15 currently-A answers to B, C, or D.
  ('05a330fa-4540-44d0-be7f-27aaed1459e4', 0, 1, 4),
  ('528e0bbd-c6d6-459a-831f-18ccaba42ae8', 0, 1, 4),
  ('a4861f50-118f-489a-9af7-17d4f1b83312', 0, 1, 4),
  ('4bf1032b-29ac-42d9-b638-cb7a0c3087b9', 0, 1, 4),
  ('b2fb6bb4-5e66-404a-8ce9-9224cf4c54a8', 0, 1, 4),
  ('04ee08c9-36d8-4ce3-a7b0-ec1c7c36f162', 0, 1, 4),
  ('7560eb7b-9347-46c2-a42a-0f5569d6c69d', 0, 2, 4),
  ('e46864d1-13a6-4675-8e9c-38e358f84e62', 0, 2, 4),
  ('be2f1b53-5a44-48ea-bc3c-5eeb0917dfd3', 0, 2, 4),
  ('85eedd26-59ad-437b-b160-26a95214affb', 0, 2, 4),
  ('1ba1757e-4e2b-466f-bbd8-1cfe02ca025a', 0, 3, 4),
  ('19525d91-e8ce-49ed-9337-69e0561fd2ea', 0, 3, 4),
  ('c9b1a398-a543-4078-8013-260b52176c53', 0, 3, 4),
  ('82714179-21c3-42d2-a218-ee93d30aea52', 0, 3, 4),
  ('c4e41ee1-4e35-4153-a34d-3120ad882167', 0, 3, 4),

  -- Five-choice questions: move one B answer to A and one B answer to E.
  ('60ace324-e352-46f9-bcb9-5d33a1407cd7', 1, 0, 5),
  ('8fde25f5-8665-4925-aa13-45d68ad5443a', 1, 4, 5);

do $$
declare
  matched_count integer;
begin
  select count(*)
  into matched_count
  from public.questions q
  join answer_position_updates u on u.id = q.id
  where q.correct_option = u.expected_correct_option
    and jsonb_array_length(q.options) = u.option_count;

  if matched_count <> 17 then
    raise exception 'Safety check failed: expected 17 matching questions, found %. No changes were made.', matched_count;
  end if;
end $$;

update public.questions q
set
  options = (
    select jsonb_agg(
      case
        when item.ordinality - 1 = u.new_correct_option then q.options -> u.expected_correct_option
        when item.ordinality - 1 = u.expected_correct_option then q.options -> u.new_correct_option
        else item.value
      end
      order by item.ordinality
    )
    from jsonb_array_elements(q.options) with ordinality as item(value, ordinality)
  ),
  correct_option = u.new_correct_option
from answer_position_updates u
where q.id = u.id;

commit;

-- Verification: expected results are 4-choice A=14/B=15/C=14/D=14
-- and 5-choice A=3/B=4/C=3/D=4/E=3. True/False is excluded.
select
  jsonb_array_length(options) as option_count,
  chr(65 + correct_option) as correct_answer_letter,
  count(*) as question_count
from public.questions
where jsonb_array_length(options) > 2
group by jsonb_array_length(options), chr(65 + correct_option)
order by option_count, correct_answer_letter;
