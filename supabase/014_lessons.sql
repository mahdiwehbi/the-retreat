-- WASH Retreat, part 14: lessons learned in the Flood Watch format, and Flood Watch uses them.
-- A) Upstream: each team gets a sealed theme card and fills "what we would do differently",
--    then everyone gives 10 points to the most useful changes.
-- B) Flood Watch: each 72-hour plan must use at least 2 lessons from the morning wall.

update activities set position = 5,
  title = 'What we would do differently',
  options = '{"fields": [{"type": "text", "label": "What happened (from the wall)"}, {"type": "list", "label": "What we would do differently", "tags": ["Start", "Stop", "Continue"]}, {"type": "text", "label": "Who owns it"}], "prompts": ["Herons · Coordination and information flow: meetings, reporting, data, who decided what.", "Kingfishers · Delivery in collective shelters: water trucking, kits, latrines, desludging.", "Flamingos · Partners, government and the Water Establishments: roles, handover, gaps."]}'::jsonb
  where position = 7 and kind = 'team';

do $$
begin
  if not exists (select 1 from activities where position = 6 and kind = 'allocate') then
    insert into activities (position, kind, title, options) values (6, 'allocate', 'Give 10 points to the most useful changes', '{"items": [], "budget": 10}'::jsonb);
  end if;
end $$;

update activities set title = 'What if? Our 72-hour plan (use at least 2 lessons from this morning)',
  options = jsonb_set(options, '{fields}', (options->'fields') || '[{"type": "list", "label": "Lessons from this morning we applied"}]'::jsonb)
  where position = 27 and kind = 'team' and not (options::text like '%Lessons from this morning%');
update activities set title = 'Score the plans: 10 points for realism and for using the lessons' where position = 28 and kind = 'allocate';
