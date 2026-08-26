-- Run once in Supabase Dashboard > SQL Editor.
-- Adds self-contained training cards and trivia based on the Arden materials.
-- Existing records are preserved. Matching prompts and titles are not added twice.

begin;

with new_questions (prompt, options, correct_option, explanation, topic) as (
  values
    ($q$How often should a routine head-to-tail wellness assessment be performed for a pet?$q$,
      jsonb_build_array($q$Only after an emergency$q$,$q$Once every six months$q$,$q$About once each week$q$,$q$Only during a veterinary visit$q$),
      2::smallint, $q$A routine head-to-tail wellness assessment can be performed about once each week, in a calm and distraction-free setting.$q$, $q$Wellness assessment$q$),
    ($q$During a routine paw check, what should you look for between a pet's toes?$q$,
      jsonb_build_array($q$Only the color of the fur$q$,$q$Ticks, foxtails, or other foreign objects$q$,$q$Whether the pet wants a treat$q$,$q$Whether the nails are painted$q$),
      1::smallint, $q$Check between the toes for ticks, foxtails, or other foreign objects, and check paw pads for cuts or tears.$q$, $q$Wellness assessment$q$),
    ($q$Which is an appropriate way to safely handle a frightened or unsafe cat?$q$,
      jsonb_build_array($q$Force the cat to stay still by scruffing it$q$,$q$Chase the cat into an open room$q$,$q$Approach face-to-face and make quick movements$q$,$q$Close off exits and use a towel wrap or carrier approach when needed$q$),
      3::smallint, $q$Close exits first. Use the least force necessary and consider a towel wrap, laundry basket, or top-loading carrier rather than forcing or scruffing the cat.$q$, $q$Cat safety$q$),
    ($q$During a pet's seizure, which action helps reduce the risk of injury?$q$,
      jsonb_build_array($q$Move other pets away and cushion nearby furniture$q$,$q$Put your fingers in the pet's mouth$q$,$q$Hold the pet down firmly$q$,$q$Give food or water immediately$q$),
      0::smallint, $q$Do not restrain the pet or put fingers in its mouth. Protect it from injury by moving other pets away and cushioning nearby furniture.$q$, $q$Seizures$q$),
    ($q$An unconscious pet has a heartbeat but is not breathing. Which response is appropriate?$q$,
      jsonb_build_array($q$Wait until the pet starts breathing on its own$q$,$q$Begin rescue breathing$q$,$q$Give the pet food or water$q$,$q$Apply a leg bandage$q$),
      1::smallint, $q$When a pet has a heartbeat but is not breathing, provide rescue breathing and assess after one minute.$q$, $q$Emergency response$q$),
    ($q$Which practice may help reduce a dog's bloat risk after eating?$q$,
      jsonb_build_array($q$Encourage vigorous exercise immediately after every meal$q$,$q$Offer a large second meal right away$q$,$q$Give only ice water after eating$q$,$q$Limit activity after meals$q$),
      3::smallint, $q$Slow bowls or food puzzles and limiting activity after meals may help reduce bloat risk.$q$, $q$Bloat$q$),
    ($q$Which combination can be a rapid warning sign of bloat in a dog?$q$,
      jsonb_build_array($q$Normal appetite, calm behavior, and a smaller abdomen$q$,$q$Sneezing, ear scratching, and watery eyes$q$,$q$Dry heaves, excessive drooling, and an enlarging abdomen$q$,$q$A single loose hair and a normal appetite$q$),
      2::smallint, $q$Bloat warning signs can include dry heaves, excessive drooling, attempted vomiting, and an abdomen that swells and grows larger.$q$, $q$Bloat$q$),
    ($q$Which change at a wound site can indicate infection?$q$,
      jsonb_build_array($q$Swelling, pus, or a foul odor$q$,$q$A clean and dry wound edge$q$,$q$Normal movement after rest$q$,$q$A calm response to gentle handling$q$),
      0::smallint, $q$Watch for swelling, pus, or a foul odor at a wound site, and seek veterinary guidance when concerned.$q$, $q$Wound care$q$),
    ($q$What should you do if an object is impaled in a pet?$q$,
      jsonb_build_array($q$Pull it out immediately$q$,$q$Push it farther in to make it stable$q$,$q$Cut the object off at the skin$q$,$q$Leave it in place and seek veterinary care$q$),
      3::smallint, $q$Leave an impaled object in place and seek veterinary care rather than removing or moving it.$q$, $q$Wound care$q$),
    ($q$Which set of details is useful to observe and report about a pet's urine?$q$,
      jsonb_build_array($q$Only the pet's favorite food$q$,$q$Color, odor, volume, and frequency$q$,$q$The brand of the litter box$q$,$q$Whether the pet played with a toy$q$),
      1::smallint, $q$Useful urine observations include color, odor, volume, and frequency.$q$, $q$Observation$q$),
    ($q$Before touching a pet that appears unresponsive, what is a safer first step?$q$,
      jsonb_build_array($q$Immediately place your hand in the pet's mouth$q$,$q$Move the pet by its legs$q$,$q$Call the pet's name and make a sound before touching it$q$,$q$Approach face-to-face and stare directly at it$q$),
      2::smallint, $q$Call the pet's name and make a sound before touching it, because pets can move in and out of consciousness.$q$, $q$Safety$q$)
)
insert into public.questions (prompt, options, correct_option, explanation, topic)
select prompt, options, correct_option, explanation, topic
from new_questions
where not exists (
  select 1 from public.questions existing where existing.prompt = new_questions.prompt
);

with new_cards (topic, title, body, sections) as (
  values
    ($q$Wellness assessment$q$, $q$Weekly Head-to-Tail Check: Head, Neck, and Chest$q$,
      $q$About once each week, spend roughly 10 minutes checking a pet in a calm, distraction-free setting. Regular checks help you notice changes from what is normal for that individual pet.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Head and senses', 'content', $q$Check that the eyes are clear and the pupils appear symmetrical. Look for discharge or cracks around the nose, inspect the ears, and gently check the muzzle and head for cuts, bumps, or lumps.$q$),
        jsonb_build_object('heading', 'Neck and spine', 'content', $q$With the pet sitting, gently rotate the neck left and right. Glide a hand from the neck down the spine to the base of the tail, watching for wincing, pain, cuts, bumps, or masses.$q$),
        jsonb_build_object('heading', 'Chest', 'content', $q$Observe whether breathing is smooth, rhythmic, and easy.$q$)
      )),
    ($q$Wellness assessment$q$, $q$Weekly Head-to-Tail Check: Body, Paws, and Tail$q$,
      $q$A routine wellness check can help you notice small changes before they become more serious. Support the pet gently and stop if the pet shows discomfort or becomes unsafe to handle.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Body and coat', 'content', $q$Gently check the abdomen for pain or sensitivity. Look for excessive shedding, odor, bald patches, or other coat changes.$q$),
        jsonb_build_object('heading', 'Legs and paws', 'content', $q$Support the standing pet while gently checking each leg's range of motion. Look between the toes for ticks, foxtails, or other foreign objects; check the pads for cuts or tears and the claws for overgrowth.$q$),
        jsonb_build_object('heading', 'Tail and reward', 'content', $q$Glide a hand down the tail and watch for pain, cuts, or limited range of use. End the check with a favorite treat to help make future checks cooperative.$q$)
      )),
    ($q$Cat safety$q$, $q$Safe Handling of a Frightened or Unsafe Cat$q$,
      $q$An injured or frightened cat can bite or scratch quickly. Use the least force necessary and prioritize your safety and the cat's comfort.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Set up safely', 'content', $q$Close nearby doors and other exits before handling. Do not approach the cat face-to-face or force the cat into a situation.$q$),
        jsonb_build_object('heading', 'Handling options', 'content', $q$Use a large towel for a full-body wrap, an empty laundry basket to safely contain the cat, or a feline facial muzzle when appropriate. Do not scruff the cat.$q$),
        jsonb_build_object('heading', 'Carrier tip', 'content', $q$A top-loading carrier with a towel left inside can make placement safer and more manageable.$q$)
      )),
    ($q$Observation$q$, $q$Potty Habits: Useful Information to Observe$q$,
      $q$Changes in elimination can provide useful information for a veterinarian. Observe the pet's normal habits so you can recognize and report changes.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Stool', 'content', $q$Note how often the pet defecates, how urgent it seems, and the amount produced. Bright-red blood or dark, foul-smelling stool that resembles coffee grounds are concerning findings to report promptly.$q$),
        jsonb_build_object('heading', 'Urine', 'content', $q$Observe urine color, odor, volume, and frequency. Also note straining, yowling while eliminating, abdominal pain, increased urination, or blood in the urine.$q$)
      )),
    ($q$Seizures$q$, $q$Seizure Safety: Protect, Observe, and Record$q$,
      $q$A seizure is abnormal activity in the brain. Stay calm and focus on keeping the pet safe while gathering useful information for veterinary care.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Do not restrain', 'content', $q$Do not put fingers in or around the pet's mouth, and do not try to restrain the pet.$q$),
        jsonb_build_object('heading', 'Prevent injury', 'content', $q$Move other pets away, cushion nearby furniture, dim lights, and lower shades when possible.$q$),
        jsonb_build_object('heading', 'Record changes', 'content', $q$Note when the seizure starts and stops and whether more seizures occur. Afterward, some pets may be ravenous, vomit, or pace.$q$)
      )),
    ($q$Bloat$q$, $q$Bloat: Rapid Warning Signs and Prevention Habits$q$,
      $q$Bloat can develop rapidly and is a medical emergency. Deep-chested dogs are at higher risk.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Warning signs', 'content', $q$Watch for dry heaves, excessive drooling, attempted vomiting, and an abdomen that swells and grows larger.$q$),
        jsonb_build_object('heading', 'Prevention habits', 'content', $q$Slow bowls, food puzzles, and limiting activity after meals may help reduce risk.$q$),
        jsonb_build_object('heading', 'Response', 'content', $q$Suspected bloat requires prompt veterinary care.$q$)
      )),
    ($q$Wound care$q$, $q$Wound Monitoring and Impaled Objects$q$,
      $q$After a wound has been cleaned and bleeding has been controlled, continue to observe the site and protect the pet from further injury.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Possible infection signs', 'content', $q$Watch for swelling, pus, or a foul odor at the wound site.$q$),
        jsonb_build_object('heading', 'Prevent licking', 'content', $q$Use a light bandage or a medical recovery collar to keep the pet from reaching the wound site when appropriate.$q$),
        jsonb_build_object('heading', 'Impaled object', 'content', $q$If an object is impaled in a pet, leave it in place and seek veterinary care. Do not remove it.$q$)
      )),
    ($q$Emergency response$q$, $q$Choosing the Emergency Response$q$,
      $q$The pet's breathing and heartbeat help determine the immediate response needed.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'CPR', 'content', $q$Use CPR when a pet is unconscious and not breathing and you are unsure whether there is a heartbeat. Act quickly if there is doubt after 10 to 15 seconds.$q$),
        jsonb_build_object('heading', 'Rescue breathing', 'content', $q$Use rescue breathing when a pet has a heartbeat but is not breathing. Perform one minute of rescue breathing, then assess.$q$),
        jsonb_build_object('heading', 'Pet first aid', 'content', $q$Use pet first aid when a pet has a heartbeat and is breathing but is ill or injured and not in a healthy state.$q$)
      )),
    ($q$Safety$q$, $q$Approaching a Pet That May Be Unresponsive$q$,
      $q$Pets can move in and out of consciousness, and a pet in pain or fear may bite. Take a moment to protect yourself before touching the pet.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Before touching', 'content', $q$Call the pet's name and make a sound before touching its body. Approach slowly and stay calm and confident.$q$),
        jsonb_build_object('heading', 'Protect yourself', 'content', $q$Survey the surroundings for hazards, keep fingers together when handling the pet, and ask for help when available.$q$),
        jsonb_build_object('heading', 'If safe to approach', 'content', $q$Approach from behind rather than from the front or belly area to reduce the chance of triggering a defensive response.$q$)
      ))
)
insert into public.training_cards (topic, title, body, sections)
select topic, title, body, sections
from new_cards
where not exists (
  select 1 from public.training_cards existing where existing.title = new_cards.title
);

commit;
