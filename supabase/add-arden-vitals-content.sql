-- Run this once in Supabase Dashboard > SQL Editor.
-- Adds Arden Pet First Aid 4U vitals-reference questions and training cards.
-- Existing questions, cards, employee scores, streaks, and quiz history are preserved.
-- It is safe to run again: matching question prompts and card titles will not be added twice.

begin;

with new_questions (prompt, options, correct_option, explanation, topic) as (
  values
    ($q$What is the normal respiration rate for cats?$q$,
      jsonb_build_array($q$10 to 30 breaths per minute at rest$q$,$q$80 to 90 breaths per minute at rest$q$,$q$15 to 30 breaths per minute at rest$q$,$q$20 to 40 breaths per minute at rest$q$,$q$100 to 120 breaths per minute at rest$q$),
      3::smallint, $q$To calculate breaths per minute, count the number of chest movements in 15 seconds and multiply by 4 to get the one-minute rate.$q$, $q$Pet vitals$q$),
    ($q$What is the normal respiration rate for small to medium dogs?$q$,
      jsonb_build_array($q$10 to 30 breaths per minute at rest$q$,$q$80 to 90 breaths per minute at rest$q$,$q$15 to 30 breaths per minute at rest$q$,$q$20 to 40 breaths per minute at rest$q$,$q$100 to 120 breaths per minute at rest$q$),
      2::smallint, $q$To calculate breaths per minute, count the number of chest movements in 15 seconds and multiply by 4 to get the one-minute rate.$q$, $q$Pet vitals$q$),
    ($q$What is the normal respiration rate for large dogs?$q$,
      jsonb_build_array($q$10 to 30 breaths per minute at rest$q$,$q$80 to 90 breaths per minute at rest$q$,$q$15 to 30 breaths per minute at rest$q$,$q$20 to 40 breaths per minute at rest$q$,$q$100 to 120 breaths per minute at rest$q$),
      0::smallint, $q$To calculate breaths per minute, count the number of chest movements in 15 seconds and multiply by 4 to get the one-minute rate.$q$, $q$Pet vitals$q$),
    ($q$What color will the gums be when the pet is suffering from heat stroke or exposure to toxins?$q$,
      jsonb_build_array($q$Bubblegum pink$q$,$q$Red$q$,$q$Yellow$q$,$q$Blue$q$,$q$Pale$q$),
      1::smallint, $q$These are not exhaustive associations. Any gum color other than bubblegum pink could indicate various issues.$q$, $q$Pet vitals$q$),
    ($q$What color will the gums be when the pet is suffering from liver issues or jaundice?$q$,
      jsonb_build_array($q$Bubblegum pink$q$,$q$Red$q$,$q$Yellow$q$,$q$Blue$q$,$q$Pale$q$),
      2::smallint, $q$These are not exhaustive associations. Any gum color other than bubblegum pink could indicate various issues.$q$, $q$Pet vitals$q$),
    ($q$What color will the gums be when the pet is suffering from lack of oxygen, heart disease, or hypothermia?$q$,
      jsonb_build_array($q$Bubblegum pink$q$,$q$Red$q$,$q$Yellow$q$,$q$Blue$q$,$q$Pale$q$),
      3::smallint, $q$These are not exhaustive associations. Any gum color other than bubblegum pink could indicate various issues.$q$, $q$Pet vitals$q$),
    ($q$What color will the gums be when the pet is suffering from anemia, shock, or internal bleeding?$q$,
      jsonb_build_array($q$Bubblegum pink$q$,$q$Red$q$,$q$Yellow$q$,$q$Blue$q$,$q$Pale$q$),
      4::smallint, $q$These are not exhaustive associations. Any gum color other than bubblegum pink could indicate various issues.$q$, $q$Pet vitals$q$),
    ($q$Which artery is best used for checking a pulse on your pet?$q$,
      jsonb_build_array($q$Brachial$q$,$q$Carotid$q$,$q$Caudal$q$,$q$Femoral$q$),
      3::smallint, $q$Use the femoral artery, located on the inside of the back thigh near the groin, to check a pet's pulse.$q$, $q$Pet vitals$q$),
    ($q$Where is the brachial artery located on your pet?$q$,
      jsonb_build_array($q$Along the neck, just below the jawline$q$,$q$Inside part of the upper front legs$q$,$q$On the inside of each back thigh, near the groin$q$,$q$At the tail, near the back, between the base and the anus$q$),
      1::smallint, $q$$q$, $q$Pet vitals$q$),
    ($q$Where is the carotid artery located on your pet?$q$,
      jsonb_build_array($q$Along the neck, just below the jawline$q$,$q$Inside part of the upper front legs$q$,$q$On the inside of each back thigh, near the groin$q$,$q$At the tail, near the back, between the base and the anus$q$),
      0::smallint, $q$$q$, $q$Pet vitals$q$),
    ($q$Where is the caudal artery located on your pet?$q$,
      jsonb_build_array($q$Along the neck, just below the jawline$q$,$q$Inside part of the upper front legs$q$,$q$On the inside of each back thigh, near the groin$q$,$q$At the tail, near the back, between the base and the anus$q$),
      3::smallint, $q$$q$, $q$Pet vitals$q$),
    ($q$Where is the femoral artery located on your pet?$q$,
      jsonb_build_array($q$Along the neck, just below the jawline$q$,$q$Inside part of the upper front legs$q$,$q$On the inside of each back thigh, near the groin$q$,$q$At the tail, near the back, between the base and the anus$q$),
      2::smallint, $q$$q$, $q$Pet vitals$q$)
)
insert into public.questions (prompt, options, correct_option, explanation, topic)
select prompt, options, correct_option, explanation, topic
from new_questions
where not exists (
  select 1 from public.questions existing where existing.prompt = new_questions.prompt
);

with new_cards (topic, title, body, sections) as (
  values
    ($q$Pet vitals$q$, $q$Normal Pet Temperature$q$,
      $q$Temperature is a key pet vital sign. Use a rectal thermometer to take the reading.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Normal range', 'content', $q$The normal temperature range for dogs and cats is 100 to 102.5 degrees Fahrenheit.$q$)
      )),
    ($q$Pet vitals$q$, $q$Normal Respiration Rates$q$,
      $q$Measure a pet's respiration rate at rest by counting chest movements for 15 seconds and multiplying by 4 to get a one-minute rate.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Cats', 'content', $q$20 to 40 breaths per minute at rest.$q$),
        jsonb_build_object('heading', 'Small to medium dogs', 'content', $q$15 to 30 breaths per minute at rest.$q$),
        jsonb_build_object('heading', 'Large dogs', 'content', $q$10 to 30 breaths per minute at rest.$q$)
      )),
    ($q$Pet vitals$q$, $q$Normal Heartbeat Ranges$q$,
      $q$Count pulses on the femoral artery inside the thigh for 15 seconds and multiply by 4 to get a one-minute heart rate. Puppies, kittens, cats, and small dogs have faster heart rates than large adult dogs.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Cats', 'content', $q$140 to 220 beats per minute.$q$),
        jsonb_build_object('heading', 'Small dogs', 'content', $q$100 to 140 beats per minute.$q$),
        jsonb_build_object('heading', 'Large dogs', 'content', $q$60 to 100 beats per minute.$q$)
      )),
    ($q$Pet vitals$q$, $q$Gum Color and Capillary Refill$q$,
      $q$Gently press a fingertip against the gum above the canine tooth, then release. In a healthy pet, bubblegum-pink color should return in 1 to 2 seconds.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Red gums', 'content', $q$Heat stroke or exposure to toxins.$q$),
        jsonb_build_object('heading', 'Yellow gums', 'content', $q$Liver issues or jaundice.$q$),
        jsonb_build_object('heading', 'Pale gums', 'content', $q$Anemia, shock, or internal bleeding.$q$),
        jsonb_build_object('heading', 'Blue gums', 'content', $q$Lack of oxygen, heart disease, or hypothermia.$q$)
      ))
)
insert into public.training_cards (topic, title, body, sections)
select topic, title, body, sections
from new_cards
where not exists (
  select 1 from public.training_cards existing where existing.title = new_cards.title
);

commit;
