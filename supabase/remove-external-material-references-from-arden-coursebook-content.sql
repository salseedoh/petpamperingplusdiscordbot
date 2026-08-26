-- Run this in Supabase Dashboard > SQL Editor only if the coursebook content
-- was already added with add-arden-coursebook-slides-14-46.sql.
-- It updates the employee-facing wording without adding or deleting records.

begin;

update public.questions
set explanation = $q$Do not spend a long time deciding. If there is doubt after 10 to 15 seconds, start CPR.$q$
where prompt = $q$If there is doubt after 10 to 15 seconds about whether an unresponsive pet has a heartbeat or is breathing, what should you do?$q$;

update public.questions
set prompt = $q$When should you assess a pet during CPR?$q$
where prompt = $q$According to the coursebook CPR formula, when should you assess the pet?$q$;

update public.questions
set prompt = $q$If a pet has a heartbeat but is not breathing on its own, what should you do first?$q$
where prompt = $q$If a pet has a heartbeat but is not breathing on its own, what does the coursebook direct you to do first?$q$;

update public.questions
set prompt = $q$At what body temperature is a dog or cat at risk for heat stroke?$q$,
    explanation = $q$Pets are at risk for heat stroke when body temperature rises above 103 degrees Fahrenheit.$q$
where prompt = $q$At what body temperature is a dog or cat at risk for heat stroke according to the coursebook?$q$;

update public.questions
set explanation = $q$Never use ice water. Cool the paws with cool water and wrap the torso in a cool, wet towel.$q$
where prompt = $q$Which cooling measure should NOT be used for a pet with heat stroke?$q$;

update public.training_cards
set sections = (
  select jsonb_agg(
    case
      when section ->> 'heading' = 'Hydrogen peroxide caution'
        then jsonb_set(
          section,
          '{content}',
          to_jsonb($q$Do not induce vomiting with 3-percent hydrogen peroxide without permission from a veterinarian. Never use hydrogen peroxide to induce vomiting in cats.$q$::text)
        )
      else section
    end
  )
  from jsonb_array_elements(sections) as section
)
where title = 'Poisoning: Recognition and Immediate Steps';

update public.training_cards
set sections = (
  select jsonb_agg(
    case
      when section ->> 'heading' = 'Skunk odor mixture caution'
        then jsonb_set(
          section,
          '{content}',
          to_jsonb($q$For skunk odor on the coat, use 1 quart of 3-percent hydrogen peroxide, one-quarter cup baking soda, and 1 teaspoon liquid dishwashing soap while the solution is still bubbling. Do not pre-mix and let it sit because it can have a chemical reaction and explode.$q$::text)
        )
      else section
    end
  )
  from jsonb_array_elements(sections) as section
)
where title = 'Snake Bites and Skunk Spray';

commit;
