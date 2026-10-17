-- WASH Retreat, part 27: 12 letters per team. Ali's badge only checks him in (no letter questions).
delete from hunt_finds where card_id in (select id from hunt_cards where code in ('R19', 'B19'));
delete from hunt_keys where card_id in (select id from hunt_cards where code = 'B19');
delete from hunt_cards where code = 'B19';
update hunt_cards set letter_index = null, letter_index2 = null, grp = null, points = 0 where code = 'R19';
-- Fix the test run: Kingfishers' bonus counted 14 letters; recount with 12.
update team_points p set points = 4 * n.k, reason = 'Word race questions not needed (' || n.k || ' × 4)'
  from (select t.id as team_id, (select count(*) from hunt_cards c where c.team_id = t.id and c.letter_index is not null
          and not exists (select 1 from hunt_finds x where x.card_id = c.id and x.team_id = t.id and x.correct)
          and (select count(*) from hunt_finds x where x.card_id = c.id and x.team_id = t.id and not x.correct) < 3) as k from teams t) n
  where p.team_id = n.team_id and p.reason like 'Word race questions not needed%';
