-- Run this once in Supabase Dashboard > SQL Editor.
-- Adds training cards and trivia grounded only in PPH_Coursebook_2026 slides
-- 14, 16, 18, 21, 23, 25, 31-35, 37, 39-46. Slide 27 has no instructional text.
-- Existing records are preserved. Matching prompts and titles are not added twice.

begin;

with new_questions (prompt, options, correct_option, explanation, topic) as (
  values
    ($q$If there is doubt after 10 to 15 seconds about whether an unresponsive pet has a heartbeat or is breathing, what should you do?$q$,
      jsonb_build_array($q$Wait another full minute before acting$q$,$q$Start CPR$q$,$q$Give the pet food or water$q$,$q$Move the pet to a different room$q$),
      1::smallint, $q$Do not spend a long time deciding. If there is doubt after 10 to 15 seconds, start CPR.$q$, $q$CPR$q$),
    ($q$When should you assess a pet during CPR?$q$,
      jsonb_build_array($q$After 30 compressions only$q$,$q$After 2 mouth-to-snout breaths only$q$,$q$After 30 compressions and 2 breaths, repeated twice$q$,$q$Only after arriving at a veterinary clinic$q$),
      2::smallint, $q$The formula is 30 compressions plus 2 mouth-to-snout breaths, repeated twice, then assess.$q$, $q$CPR$q$),
    ($q$For a round-chested dog lying on its side, where should hand-over-hand chest compressions be performed?$q$,
      jsonb_build_array($q$Directly over the highest point on the chest$q$,$q$Directly over the sternum while the dog is on its back$q$,$q$Only on the lower abdomen$q$,$q$At the base of the tail$q$),
      0::smallint, $q$For a round-chested dog on its side, perform hand-over-hand compressions directly over the highest point on the chest.$q$, $q$CPR$q$),
    ($q$For a keel-shaped chested dog lying on its side, where should hand-over-hand chest compressions be performed?$q$,
      jsonb_build_array($q$Directly over the heart$q$,$q$Directly over the sternum while the dog is on its back$q$,$q$At the highest point on the chest$q$,$q$On the lower abdomen$q$),
      0::smallint, $q$For a keel-shaped chest, place the dog on its side and perform hand-over-hand compressions directly over the heart.$q$, $q$CPR$q$),
    ($q$How should chest compressions be performed for a flat-chested dog?$q$,
      jsonb_build_array($q$Place the dog on its back and compress over the sternum$q$,$q$Place the dog on its side and compress at the highest point of the chest$q$,$q$Compress the lower abdomen$q$,$q$Use one hand only on the front leg$q$),
      0::smallint, $q$For flat-chested dogs, place the dog on its back and perform hand-over-hand compressions over the sternum.$q$, $q$CPR$q$),
    ($q$If a pet has a heartbeat but is not breathing on its own, what should you do first?$q$,
      jsonb_build_array($q$Perform one minute of rescue breathing$q$,$q$Immediately perform abdominal thrusts$q$,$q$Give food or water$q$,$q$Apply a warm compress$q$),
      0::smallint, $q$When a pet has a heartbeat but is not breathing, perform one minute of rescue breathing, then assess by checking for a pulse.$q$, $q$Rescue breathing$q$),
    ($q$Which pet should never be muzzled?$q$,
      jsonb_build_array($q$A pet who is choking$q$,$q$A conscious pet that is calm$q$,$q$A pet being transported in a carrier$q$,$q$A pet resting at home$q$),
      0::smallint, $q$Never muzzle a pet who is choking, vomiting, having breathing problems, or having a seizure.$q$, $q$Safety$q$),
    ($q$At what body temperature is a dog or cat at risk for heat stroke?$q$,
      jsonb_build_array($q$Above 103 degrees Fahrenheit$q$,$q$Above 99 degrees Fahrenheit$q$,$q$Below 100 degrees Fahrenheit$q$,$q$Exactly 102.5 degrees Fahrenheit$q$),
      0::smallint, $q$Pets are at risk for heat stroke when body temperature rises above 103 degrees Fahrenheit.$q$, $q$Heat stroke$q$),
    ($q$Which cooling measure should NOT be used for a pet with heat stroke?$q$,
      jsonb_build_array($q$Ice water$q$,$q$Cool water for the paws$q$,$q$A cool, wet towel around the torso$q$,$q$Removing the pet from direct heat$q$),
      0::smallint, $q$Never use ice water. Cool the paws with cool water and wrap the torso in a cool, wet towel.$q$, $q$Heat stroke$q$),
    ($q$What temperature of compress should be used on an area affected by frostbite?$q$,
      jsonb_build_array($q$A warm compress$q$,$q$Ice water$q$,$q$Hot water$q$,$q$An icy cold compress$q$),
      0::smallint, $q$Apply a warm compress to frostbite. Never use hot water.$q$, $q$Frostbite$q$),
    ($q$What should you avoid doing when warming a pet affected by frostbite?$q$,
      jsonb_build_array($q$Rubbing the pet$q$,$q$Wrapping the pet in a dry towel$q$,$q$Removing the pet from direct cold$q$,$q$Monitoring vital signs$q$),
      0::smallint, $q$Do not rub a pet with frostbite because it can cause more damage and pain.$q$, $q$Frostbite$q$),
    ($q$What is the appropriate first response for a burn after safely restraining the pet?$q$,
      jsonb_build_array($q$Apply cool, clean water with a damp cloth as a compress$q$,$q$Apply ice cubes directly to the burn$q$,$q$Wrap the burn tightly with gauze$q$,$q$Apply an over-the-counter human burn ointment$q$),
      0::smallint, $q$Gently apply cool, clean water with a damp cloth. Do not use ice cubes, gauze wraps, or human burn ointments.$q$, $q$Burns$q$),
    ($q$What should you do if blood saturates the first layer of gauze or clothing on a wound?$q$,
      jsonb_build_array($q$Apply another clean layer on top and continue direct pressure$q$,$q$Remove the first layer immediately$q$,$q$Stop applying pressure$q$,$q$Rinse the wound with hydrogen peroxide$q$),
      0::smallint, $q$Apply another clean layer on top. Do not remove the first layer because the blood is clotting.$q$, $q$Bleeding$q$),
    ($q$What can cold or swollen toes indicate after a leg bandage is applied?$q$,
      jsonb_build_array($q$The bandage is too tight$q$,$q$The bandage is too loose$q$,$q$The wound is fully healed$q$,$q$The pet needs more exercise$q$),
      0::smallint, $q$Coldness or swelling in the toes can indicate that the bandage is too tight.$q$, $q$Bandaging$q$),
    ($q$During conscious choking, what does a high-pitched wheeze called stridor signal?$q$,
      jsonb_build_array($q$A partial blockage$q$,$q$Normal breathing$q$,$q$That the pet is asleep$q$,$q$A healed airway$q$),
      0::smallint, $q$Stridor signals a partial blockage.$q$, $q$Choking$q$),
    ($q$What should you NOT do for an open fracture?$q$,
      jsonb_build_array($q$Attempt to bandage or splint it$q$,$q$Limit the pet's movement$q$,$q$Monitor vital signs$q$,$q$Transport the pet carefully to a veterinary clinic$q$),
      0::smallint, $q$Do not bandage or splint an open fracture because it can trap bacteria and infection in the limb.$q$, $q$Fractures$q$),
    ($q$Which is a warning sign of shock?$q$,
      jsonb_build_array($q$Pale gums$q$,$q$Bubblegum-pink gums$q$,$q$A strong pulse$q$,$q$Warm paw pads and limbs$q$),
      0::smallint, $q$Warning signs of shock include pale gums, a weak pulse, cool paw pads and limbs, woozy behavior, and unconsciousness.$q$, $q$Shock$q$),
    ($q$Before inducing vomiting with 3-percent hydrogen peroxide after a poisoning exposure, whose permission is required?$q$,
      jsonb_build_array($q$A veterinarian's$q$,$q$A pet store employee's$q$,$q$Any nearby friend's$q$,$q$No permission is needed$q$),
      0::smallint, $q$Do not attempt to induce vomiting using 3-percent hydrogen peroxide without permission from a veterinarian.$q$, $q$Poisoning$q$),
    ($q$Which ingredient in sugar-free gum and mints can cause severe low blood glucose, seizures, and liver failure if ingested?$q$,
      jsonb_build_array($q$Xylitol$q$,$q$Calamine$q$,$q$Sterile eye wash$q$,$q$Styptic powder$q$),
      0::smallint, $q$Sugar-free gum and mints may contain xylitol, which can cause severe low blood glucose, seizures, and liver failure.$q$, $q$Poisoning$q$),
    ($q$What should be used to remove a visible bee stinger from a pet's coat?$q$,
      jsonb_build_array($q$A credit card to scrape it out$q$,$q$Tweezers to squeeze it out$q$,$q$A hot match$q$,$q$A tight gauze wrap$q$),
      0::smallint, $q$Use a credit card to scrape out a visible stinger. Do not squeeze it with tweezers because the venom sac may rupture.$q$, $q$Bites and stings$q$),
    ($q$Which ingredient should an antihistamine for a stung pet contain, if a veterinarian advises its use?$q$,
      jsonb_build_array($q$Diphenhydramine only$q$,$q$Diphenhydramine and acetaminophen$q$,$q$Acetaminophen only$q$,$q$Cherry flavoring and acetaminophen$q$),
      0::smallint, $q$Select an antihistamine containing only diphenhydramine. Avoid products containing acetaminophen or cherry flavoring meant for children.$q$, $q$Bites and stings$q$),
    ($q$Which item should NOT be used to remove a tick from a pet?$q$,
      jsonb_build_array($q$Petroleum jelly$q$,$q$Fine-tipped tweezers$q$,$q$A tick-removal tool$q$,$q$Rubber gloves while handling the tick$q$),
      0::smallint, $q$Do not use nail polish, petroleum jelly, or a hot match. Use fine-tipped tweezers or a tick-removal tool.$q$, $q$Ticks$q$),
    ($q$What should you do with a snake after a suspected bite, if it can be done quickly and safely?$q$,
      jsonb_build_array($q$Take a photo to help identify it$q$,$q$Attempt to kill it$q$,$q$Pick it up for transport$q$,$q$Ignore the pet and follow the snake$q$),
      0::smallint, $q$If it can be done quickly and safely, take a photo to help identify whether the snake is venomous or non-venomous. Do not attempt to kill it.$q$, $q$Snake bites$q$),
    ($q$Why should a skunk-odor-removal solution made with hydrogen peroxide, baking soda, and dishwashing soap not be pre-mixed and allowed to sit?$q$,
      jsonb_build_array($q$It can have a chemical reaction and explode$q$,$q$It becomes a tick repellent$q$,$q$It turns into ice water$q$,$q$It makes gauze sterile$q$),
      0::smallint, $q$Do not pre-mix and let the solution sit because it can have a chemical reaction and explode.$q$, $q$Skunk spray$q$),
    ($q$Which situation requires veterinary assessment even if the pet has been successfully revived?$q$,
      jsonb_build_array($q$Bloat$q$,$q$A routine meal$q$,$q$Normal play after rest$q$,$q$A calm nap$q$),
      0::smallint, $q$Bloat is one of the listed situations that requires veterinary assessment even after successful revival.$q$, $q$Veterinary care$q$)
)
insert into public.questions (prompt, options, correct_option, explanation, topic)
select prompt, options, correct_option, explanation, topic
from new_questions
where not exists (
  select 1 from public.questions existing where existing.prompt = new_questions.prompt
);

with new_cards (topic, title, body, sections) as (
  values
    ($q$CPR$q$, $q$Cardiopulmonary Arrest: Act Quickly$q$,
      $q$Cardiopulmonary arrest occurs when the heart has stopped beating and the pet has stopped breathing. Blood flow and oxygen delivery have ceased, and vital organs can develop irreversible damage within minutes.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Possible causes', 'content', $q$Trauma or electrocution; extremely cold or hot weather; toxins; airway obstruction; and heart, lung, or other chronic or sudden-onset diseases.$q$),
        jsonb_build_object('heading', 'CPR decision', 'content', $q$If there is doubt after 10 to 15 seconds about whether an unresponsive pet has a heartbeat or is breathing, start CPR. Minimize pauses.$q$),
        jsonb_build_object('heading', 'Formula', 'content', $q$30 compressions plus 2 mouth-to-snout breaths, repeated twice, then assess.$q$)
      )),
    ($q$CPR$q$, $q$Dog CPR Sequence$q$,
      $q$For an unconscious, non-breathing dog, position the dog on either side and kneel with the dog's back against your knees.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Prepare', 'content', $q$Align the head with the spine, pull out the tongue, and finger sweep the mouth.$q$),
        jsonb_build_object('heading', 'Compressions', 'content', $q$Use hand-over-hand placement appropriate to chest shape. Lock your elbows, position shoulders directly over your hands, and compress one-third to one-half the width of the chest.$q$),
        jsonb_build_object('heading', 'Cycle', 'content', $q$Perform 30 compressions, then 2 mouth-to-snout breaths. Repeat the sequence, then check the femoral pulse on the inside of the back thigh near the groin.$q$)
      )),
    ($q$CPR$q$, $q$Dog CPR: Chest Shape and Hand Placement$q$,
      $q$Dog chest shape determines where compressions are performed.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Round chest', 'content', $q$With the dog on its side, perform hand-over-hand compressions over the highest point of the chest.$q$),
        jsonb_build_object('heading', 'Keel-shaped chest', 'content', $q$With the dog on its side, perform hand-over-hand compressions directly over the heart.$q$),
        jsonb_build_object('heading', 'Flat chest', 'content', $q$Place the dog on its back and perform hand-over-hand compressions over the sternum.$q$),
        jsonb_build_object('heading', 'Small dog under 10 pounds', 'content', $q$Place the dog on its side. Wrap the dominant hand over the sternum with the thumb over the heart and point the thumb toward the spine; squeeze with the dominant hand. Two hands on the heart may also be used.$q$)
      )),
    ($q$CPR$q$, $q$Cat CPR Hand Placement$q$,
      $q$For an unconscious, non-breathing cat, position the cat on either side with the back against your knees, or on a hard surface.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Hand placement', 'content', $q$Align the head with the spine. Wrap the dominant hand over the sternum, place the thumb over the heart and point it toward the spine, then hold the spine with the other hand.$q$),
        jsonb_build_object('heading', 'Cycle', 'content', $q$Squeeze with the dominant hand for 30 compressions at a depth of one-third to one-half the chest width. Give 2 mouth-to-snout breaths, repeat the cycle, then check the femoral pulse inside the back thigh near the groin.$q$),
        jsonb_build_object('heading', 'Obese cats', 'content', $q$If one-hand compressions are inadequate, use two hands with fingers interlaced directly over the heart and the heel of the hand in contact with the chest.$q$)
      )),
    ($q$Rescue breathing$q$, $q$Rescue Breathing: Pulse Present$q$,
      $q$Mouth-to-snout breathing brings oxygen into the pet and removes carbon dioxide from the lungs. Use rescue breathing when the pet has a heartbeat but is not breathing on its own.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'One-minute response', 'content', $q$Perform one minute of rescue breathing, then check for a pulse to determine whether to continue rescue breathing or perform CPR.$q$),
        jsonb_build_object('heading', 'Steps', 'content', $q$Align the snout with the spine, pull the tongue forward, hold the mouth closed, seal your lips over the nostrils, and blow firmly enough to see the chest rise.$q$),
        jsonb_build_object('heading', 'If the chest does not rise', 'content', $q$Open the mouth and finger sweep for a possible blockage. If no pulse is found after one minute, perform CPR.$q$)
      )),
    ($q$Safety$q$, $q$Safe Restraint and Muzzling$q$,
      $q$When dealing with a conscious animal, safety comes first. Protect yourself from being bitten or clawed while using the least force necessary and keeping the pet comfortable.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Approach', 'content', $q$Approach with caution, avoid sudden movements, use a calm reassuring tone, and control the pet's movement.$q$),
        jsonb_build_object('heading', 'Never muzzle', 'content', $q$Do not muzzle a pet who is choking, vomiting, experiencing breathing problems, or having a seizure.$q$)
      )),
    ($q$Heat stroke$q$, $q$Heat Stroke: Warning Signs and Response$q$,
      $q$Heat stroke, or hyperthermia, can result from hot environments, confined spaces with little ventilation, overexertion, or parked cars when outside temperatures rise above 70 degrees Fahrenheit.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Risk and signs', 'content', $q$Pets are at risk when temperature rises above 103 degrees Fahrenheit. Signs include excessive panting, dehydration, bright red gums, rapid heart rate, foaming at the mouth, acting drunk, vomiting, and loss of consciousness.$q$),
        jsonb_build_object('heading', 'Response', 'content', $q$Remove the pet from direct heat, place paws in cool water, wrap the torso in a cool wet towel, monitor vital signs, and transport immediately to a veterinary clinic. Call ahead.$q$),
        jsonb_build_object('heading', 'Do not use ice water', 'content', $q$Ice water can shock the pet's system and cause veins to contract and shrink.$q$)
      )),
    ($q$Frostbite$q$, $q$Frostbite: Warning Signs and Response$q$,
      $q$Prolonged cold exposure can cause frostbite, the freezing of skin and tissue. It commonly affects areas farthest from the heart, including ears, paws, tail, and scrotum.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Warning signs', 'content', $q$Blue gums; swollen red and painful skin; hard or pale skin; and, in advanced stages, areas that look black and dead.$q$),
        jsonb_build_object('heading', 'Response', 'content', $q$Remove the pet from direct cold, apply a warm compress, wrap in a dry towel or coat, monitor vital signs, and transport immediately to a veterinary clinic. Call ahead.$q$),
        jsonb_build_object('heading', 'Avoid', 'content', $q$Never use hot water or rub the pet; both can cause more damage and pain.$q$)
      )),
    ($q$Burns$q$, $q$Burn Care: Cool Water and Veterinary Evaluation$q$,
      $q$Chemical, electrical, and thermal burns can injure the skin. Burned pets should be evaluated by a veterinarian because it may be difficult to tell the severity of a burn from appearance or pain alone.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'First response', 'content', $q$Safely restrain the pet. Gently apply cool, clean water with a damp cloth as a compress and alert the veterinary clinic that you are on the way.$q$),
        jsonb_build_object('heading', 'Avoid', 'content', $q$Do not apply a gauze pad or wrap to the burn, ice cubes, human over-the-counter burn ointments, vinegar, lemon juice, or another substance to neutralize a chemical burn.$q$),
        jsonb_build_object('heading', 'Hot spots', 'content', $q$For inflamed areas caused by licking, biting, or scratching, shave the area, clean with warm water, apply a pet-safe topical, and use a medical recovery collar. Seek veterinary care if the problem persists.$q$)
      )),
    ($q$Bleeding$q$, $q$Bleeding: Direct Pressure and Layering Gauze$q$,
      $q$Arterial bleeding is spurting and bright red, venous bleeding is a slower dark-red flow, and capillary bleeding is superficial oozing. A laceration of a large artery or vein can become life-threatening within minutes.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Control bleeding', 'content', $q$Use sterile gauze and direct pressure. If sterile gauze is unavailable, use a clean towel, T-shirt, or other clean fabric.$q$),
        jsonb_build_object('heading', 'If material saturates', 'content', $q$Apply another clean layer on top and continue direct pressure. Do not remove the first layer because the blood is clotting.$q$),
        jsonb_build_object('heading', 'Severe leg or foot cuts', 'content', $q$Raise the leg above the pet's heart. For arterial bleeding, apply pressure on the main artery nearest the wound for about 45 seconds.$q$)
      )),
    ($q$Bandaging$q$, $q$Bandaging: Head, Legs, and Abdominal Wounds$q$,
      $q$Bandages should control bleeding and stay secure without cutting off an airway or circulation.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Head bandage', 'content', $q$Use long gauze or torn strips of a T-shirt or sheet for bleeding ears. Avoid tight wrapping, do not cover the eyes, tape the front edges with hair included, and monitor for facial swelling or breathing difficulty.$q$),
        jsonb_build_object('heading', 'Leg bandage', 'content', $q$Cover limb wounds with a gauze pad, rolled cotton gauze, then stretch gauze. Keep it snug but not tight, and check toes for swelling or coldness.$q$),
        jsonb_build_object('heading', 'Severe abdominal wounds', 'content', $q$Lightly wrap the torso to cover exposed organs and reduce blood flow, then place the injured pet wound-side down in the vehicle.$q$),
        jsonb_build_object('heading', 'Wound care', 'content', $q$Once bleeding stops, wash the wound gently with warm water and apply sterile water-based lubricant before bandaging. Never use hydrogen peroxide on wounds.$q$)
      )),
    ($q$Choking$q$, $q$Choking: Recognize and Respond$q$,
      $q$A choking pet may stand wide-legged, cough, gasp, thrust the head forward, paw at the mouth, or develop pale or blue gums. Choking may be conscious, unconscious, or witnessed unconscious after collapse.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Conscious choking', 'content', $q$Remove distractions and monitor. A high-pitched wheeze called stridor signals a partial blockage. For medium or large dogs, perform inward and downward chest thrusts; for cats and small dogs, place head down between your knees and perform down/in chest thrusts.$q$),
        jsonb_build_object('heading', 'Witnessed collapse', 'content', $q$Note the time, extend the head and neck, pull the tongue forward, look for an object, and give a breath. If it does not go in after repositioning the head, begin CPR.$q$),
        jsonb_build_object('heading', 'Unconscious choking', 'content', $q$Perform CPR and assess by checking the femoral pulse. Contact the nearest veterinary clinic and bring the pet as soon as possible.$q$)
      )),
    ($q$Fractures$q$, $q$Broken Bones and Sprains$q$,
      $q$Closed fractures have intact skin over the fracture. Open fractures expose the bone through an open skin area. Only X-rays at a veterinary clinic can confirm a simple fracture or sprain.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Open fracture warning', 'content', $q$Do not attempt to bandage, splint, reset, or apply antiseptics to an open fracture.$q$),
        jsonb_build_object('heading', 'Stabilize', 'content', $q$Limit movement. Immobilize the limb as found using splints above and below with cushioning, then use rolled gauze, a triangular bandage, or a bandana tied in a bow rather than a knot.$q$),
        jsonb_build_object('heading', 'Transport', 'content', $q$Monitor vital signs for shock or other injuries. Use towels, blankets, or an Ikea blue bag as a temporary gurney and transport carefully to a veterinary clinic. Call ahead.$q$)
      )),
    ($q$Shock$q$, $q$Shock: Warning Signs and First Aid$q$,
      $q$Shock is life-threatening and occurs when oxygen and blood flow to internal organs drop. Untreated shock can progress to cardiac arrest and death.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Possible causes', 'content', $q$Severe allergic reaction, bloat, severe blood loss or infection, electrocution, poison exposure, or severe trauma with internal bleeding.$q$),
        jsonb_build_object('heading', 'Warning signs', 'content', $q$Pale gums, weak pulse, cool paw pads and limbs, woozy behavior, and unconsciousness.$q$),
        jsonb_build_object('heading', 'Response', 'content', $q$Control bleeding, provide CPR or rescue breathing if the pet is unconscious and has no heartbeat or pulse, keep the pet warm, stabilize injuries, and transport safely to a veterinary clinic. Call ahead.$q$)
      )),
    ($q$Poisoning$q$, $q$Poisoning: Recognition and Immediate Steps$q$,
      $q$Poisons can include plants, food, bee or snake venom, rat bait, pool chemicals, household cleaners, and insecticides.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Warning signs', 'content', $q$Vomiting or diarrhea, excessive salivation, difficulty breathing, muscle tremors, excitability and rapid heartbeat, seizures, and possible loss of consciousness.$q$),
        jsonb_build_object('heading', 'Response', 'content', $q$Make sure breathing is normal and not labored, limit movement by wrapping in a towel or holding the pet, identify the poison, collect a sample in a resealable bag, and bring it to the veterinary clinic.$q$),
        jsonb_build_object('heading', 'Hydrogen peroxide caution', 'content', $q$Do not induce vomiting with 3-percent hydrogen peroxide without permission from a veterinarian. Never use hydrogen peroxide to induce vomiting in cats.$q$)
      )),
    ($q$Poisoning$q$, $q$Common Household and Plant Poisons$q$,
      $q$Keep potential toxins out of reach. Sugar-free gum and mints can contain xylitol, which can cause severe low blood glucose, seizures, and liver failure if ingested.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Examples of household poisons', 'content', $q$Acetaminophen, alcoholic beverages, antifreeze, batteries, bleach, detergents and fabric softeners, fertilizers and insecticides, paint, sleeping pills, snail and slug bait, and windshield-wiper fluid.$q$),
        jsonb_build_object('heading', 'Examples of poisonous plants', 'content', $q$Amaryllis, sago palm, avocado, lilies, English ivy, foxglove, oleander, philodendron, poinsettias, rhododendron, and tulips.$q$),
        jsonb_build_object('heading', 'Pennies', 'content', $q$Pennies minted since 1982 contain zinc and can be fatal if swallowed by a dog.$q$)
      )),
    ($q$Bites and stings$q$, $q$Bee and Wasp Stings$q$,
      $q$Mild stings may cause localized swelling or tenderness. Severe reactions can include swollen eyes or muzzle, fat ears, hives, or welts.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Stinger and swelling care', 'content', $q$If visible, scrape the stinger out with a credit card. Do not squeeze it with tweezers. Limit movement and apply a cool wet compress, not an icy cold compress.$q$),
        jsonb_build_object('heading', 'Medication caution', 'content', $q$A veterinarian may advise an antihistamine. Select one containing only diphenhydramine; avoid products containing acetaminophen or cherry flavoring meant for children.$q$),
        jsonb_build_object('heading', 'Emergency signs', 'content', $q$Seek veterinary care if swelling balloons, gums turn white or light gray, or the pet drools, vomits, has diarrhea, difficulty breathing, confusion, or wobbliness.$q$)
      )),
    ($q$Ticks and spiders$q$, $q$Tick Removal and Spider Bite Concerns$q$,
      $q$Ticks can transmit disease. Use protective handling and appropriate tick-removal tools.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Tick removal', 'content', $q$Wear rubber gloves. Use fine-tipped tweezers or a tick-removal tool, grasp the tick by its head, and steadily pull it away from the skin.$q$),
        jsonb_build_object('heading', 'Avoid', 'content', $q$Do not use nail polish, petroleum jelly, or a hot match. These methods are ineffective and can cause the tick to emit more disease-carrying saliva.$q$),
        jsonb_build_object('heading', 'After removal and spiders', 'content', $q$Dispose of the tick in isopropyl alcohol, apply antiseptic at the removal site, and wash hands. Black widow and brown recluse bites need veterinary care immediately when there is drooling, vomiting or diarrhea, difficulty breathing, or seizures.$q$)
      )),
    ($q$Snake bites and skunk spray$q$, $q$Snake Bites and Skunk Spray$q$,
      $q$A snake bite is a major medical emergency. A pet may be weak, salivate excessively, act nervous, vomit, or have convulsions.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Snake-bite response', 'content', $q$If quickly and safely possible, take a photo of the snake. Do not attempt to kill it. Restrict movement, remove the collar in case of neck swelling, monitor vital signs, treat for shock if needed, and contact the veterinary clinic while en route.$q$),
        jsonb_build_object('heading', 'Skunk spray in the eyes', 'content', $q$Rinse the eyes with pet-safe eye wash and saline solution.$q$),
        jsonb_build_object('heading', 'Skunk odor mixture caution', 'content', $q$For skunk odor on the coat, use 1 quart of 3-percent hydrogen peroxide, one-quarter cup baking soda, and 1 teaspoon liquid dishwashing soap while the solution is still bubbling. Do not pre-mix and let it sit because it can have a chemical reaction and explode.$q$)
      )),
    ($q$Veterinary care$q$, $q$When Veterinary Assessment Is Needed$q$,
      $q$Even if a dog or cat has been successfully revived, veterinary assessment is still needed for specific emergencies.$q$,
      jsonb_build_array(
        jsonb_build_object('heading', 'Urgent situations', 'content', $q$Arterial bleeding; massive head, abdomen, or chest trauma; broken leg or fractured ribs; deep cuts, bites, or puncture wounds; snake bites; poisoning; shock; bloat; unconsciousness; a first-time or prolonged seizure; inability to walk; or difficulty breathing.$q$),
        jsonb_build_object('heading', 'Prepare', 'content', $q$Keep primary-veterinarian and nearest emergency-veterinary-clinic contact information in your cell phone, glove compartment, and on the refrigerator.$q$)
      ))
)
insert into public.training_cards (topic, title, body, sections)
select topic, title, body, sections
from new_cards
where not exists (
  select 1 from public.training_cards existing where existing.title = new_cards.title
);

commit;
