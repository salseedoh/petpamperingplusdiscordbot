-- Run this entire file once in Supabase Dashboard > SQL Editor.
-- Adds optional image support to trivia questions and creates the dog-heart question.

begin;

alter table public.questions add column if not exists image_filename text;

insert into public.questions (prompt, options, correct_option, explanation, topic, image_filename)
select
  $q$Look at the labeled dog anatomy image. Which label identifies the heart?$q$,
  jsonb_build_array($q$A$q$, $q$B$q$, $q$C$q$, $q$D$q$, $q$E$q$),
  3::smallint,
  $q$Label D identifies the heart.$q$,
  $q$Dog anatomy$q$,
  $q$DogAnatomy.png$q$
where not exists (
  select 1
  from public.questions
  where prompt = $q$Look at the labeled dog anatomy image. Which label identifies the heart?$q$
);

commit;
