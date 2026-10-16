-- WASH Retreat, part 13: the 2026 escalation (2 March 2026).
-- Coffee quiz figures come from the Emergency WASH Response Dashboard (ActivityInfo), as of 16 Oct 2026.

update activities set title = 'Where were you in the first week of the escalation (2 March 2026)?' where position = 1;
do $$
declare v uuid;
begin
  select id into v from activities where position = 9 and kind = 'quiz';
  if v is not null then
    update activities set title = 'Since the escalation of 2 March 2026, how many hygiene kits have partners reported in ActivityInfo?', options = '["About 15,000", "About 50,000", "About 150,000", "About 500,000"]'::jsonb where id = v;
    insert into activity_keys (activity_id, correct) values (v, 2) on conflict (activity_id) do update set correct = excluded.correct;
    delete from responses where activity_id = v;
  end if;
  select id into v from activities where position = 10 and kind = 'quiz';
  if v is not null then
    update activities set title = 'Bottled water reported since 2 March 2026?', options = '["About 360,000 litres", "About 1.2 million litres", "About 3.6 million litres", "About 12 million litres"]'::jsonb where id = v;
    insert into activity_keys (activity_id, correct) values (v, 2) on conflict (activity_id) do update set correct = excluded.correct;
    delete from responses where activity_id = v;
  end if;
  select id into v from activities where position = 11 and kind = 'quiz';
  if v is not null then
    update activities set title = 'Water trucked since 2 March 2026?', options = '["About 21,000 m³", "About 213,000 m³", "About 2.1 million m³", "About 6,700 m³"]'::jsonb where id = v;
    insert into activity_keys (activity_id, correct) values (v, 1) on conflict (activity_id) do update set correct = excluded.correct;
    delete from responses where activity_id = v;
  end if;
  select id into v from activities where position = 12 and kind = 'quiz';
  if v is not null then
    update activities set title = 'Fuel reported for water pumps and stations?', options = '["About 100,000 litres", "About 250,000 litres", "About 1 million litres", "About 5 million litres"]'::jsonb where id = v;
    insert into activity_keys (activity_id, correct) values (v, 2) on conflict (activity_id) do update set correct = excluded.correct;
    delete from responses where activity_id = v;
  end if;
  select id into v from activities where position = 13 and kind = 'quiz';
  if v is not null then
    update activities set title = 'How many water stations have partners supported?', options = '["32", "127", "324", "1,040"]'::jsonb where id = v;
    insert into activity_keys (activity_id, correct) values (v, 2) on conflict (activity_id) do update set correct = excluded.correct;
    delete from responses where activity_id = v;
  end if;
  select id into v from activities where position = 14 and kind = 'quiz';
  if v is not null then
    update activities set title = 'Latrines rehabilitated?', options = '["About 350", "About 1,000", "About 3,500", "About 9,000"]'::jsonb where id = v;
    insert into activity_keys (activity_id, correct) values (v, 2) on conflict (activity_id) do update set correct = excluded.correct;
    delete from responses where activity_id = v;
  end if;
  select id into v from activities where position = 15 and kind = 'quiz';
  if v is not null then
    update activities set title = 'After hygiene kits, which kit was distributed the most?', options = '["Baby kits", "MHM kits", "Incontinence kits", "Centre kits"]'::jsonb where id = v;
    insert into activity_keys (activity_id, correct) values (v, 1) on conflict (activity_id) do update set correct = excluded.correct;
    delete from responses where activity_id = v;
  end if;
  select id into v from activities where position = 16 and kind = 'quiz';
  if v is not null then
    update activities set title = 'Safe water in collective shelters: how close are we to the 200,000 people target?', options = '["About a quarter", "About half", "Almost all of it", "We passed it twice over"]'::jsonb where id = v;
    insert into activity_keys (activity_id, correct) values (v, 2) on conflict (activity_id) do update set correct = excluded.correct;
    delete from responses where activity_id = v;
  end if;
end $$;

-- Badge questions: R01 now asks about 2026; R02 says which ceasefire.
update hunt_cards set prompt = 'On which day did the 2026 escalation start?', options = '["2 March 2026", "23 September 2024", "8 October 2023", "15 March 2026"]'::jsonb where code = 'R01';
update hunt_keys set answer = '0' where card_id = (select id from hunt_cards where code = 'R01');
update hunt_cards set prompt = 'On which date did the November 2024 ceasefire start? (day and month)' where code = 'R02';
