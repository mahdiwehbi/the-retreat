-- WASH Retreat, part 21: comments from the second test run.
-- Upstream: only "what we would do differently", tagged start / stop / continue.
update activities set options = jsonb_build_object('fields', '[{"type": "list", "label": "What we would do differently", "tags": ["Start", "Stop", "Continue"]}]'::jsonb, 'prompts', options->'prompts')
  where position = 5 and kind = 'team';
-- Every letter question is multiple choice (no typing dates or names).
update hunt_cards set kind = 'quiz', options = '["27 November 2024", "23 September 2024", "8 October 2024", "1 December 2024"]'::jsonb where code = 'R02';
update hunt_keys set answer = '0' where card_id = (select id from hunt_cards where code = 'R02');
update hunt_cards set kind = 'quiz', options = '["Aley", "Chouf", "Saida", "Beirut"]'::jsonb where code = 'R03';
update hunt_keys set answer = '0' where card_id = (select id from hunt_cards where code = 'R03');
