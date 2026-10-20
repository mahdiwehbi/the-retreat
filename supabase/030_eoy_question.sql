-- WASH Retreat, part 30: one open question for the End-of-Year WaSH Sector Workshop Planning slot.
insert into activities (position, kind, title, options)
  select 31, 'open', 'End-of-year workshop: what other topic should we add?', '[]'::jsonb
  where not exists (select 1 from activities where position = 31);
