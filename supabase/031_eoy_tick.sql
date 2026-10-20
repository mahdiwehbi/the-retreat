-- WASH Retreat, part 31: End-of-year workshop planning = tick the topics, then "what did we miss?".
-- "One word for how you leave today" moves from 32 to 33 to make room.
update activities set position = 33 where position = 32 and title = 'One word for how you leave today' and not exists (select 1 from activities where position = 33);
update activities set kind = 'allocate', title = 'End-of-year workshop: which topics should we cover?',
  options = jsonb_build_object('tick', true, 'budget', 10, 'items', '["Water quality", "Emergency response", "Informal settlements (WAP)", "Sector transition", "Coordination & partnerships", "Looking ahead (2027)", "Hygiene promotion", "Inclusion (GESI)", "Innovation & technology", "Policy and advocacy"]'::jsonb)
  where position = 31;
insert into activities (position, kind, title, options)
  select 32, 'open', 'End-of-year workshop: what did we miss? What should we add?', '[]'::jsonb
  where not exists (select 1 from activities where position = 32);
select position, kind, title from activities where position between 30 and 33 order by position;
