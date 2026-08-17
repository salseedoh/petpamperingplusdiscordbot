-- Run this once in Supabase Dashboard > SQL Editor.
-- Clears only the generated placeholder explanation, preserving any explanation
-- that has been entered manually.

update public.questions
set explanation = '', updated_at = now()
where explanation = 'Refer to the Pet First Aid course materials for additional context.';
