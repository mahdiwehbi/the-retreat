-- WASH Retreat, part 32: Issa Wehbi is not coming; Ali Audi takes his two Kingfishers questions and letters.
-- Ali's badge (R19) gets Issa's badge question (R12); a new B19 gets Issa's second question (B12),
-- chained after R19 like every badge without a room card. Issa's cards stop giving letters.
delete from hunt_finds where card_id in (select id from hunt_cards where code in ('R12', 'B12', 'R19', 'B19'));
delete from race_board where code in ('R12', 'B12');
update hunt_cards a set kind = b.kind, prompt = b.prompt, options = b.options, letter_index = b.letter_index, letter_index2 = null,
  grp = b.grp, points = b.points, team_id = b.team_id, holder = 'Ali Audi'
  from hunt_cards b where a.code = 'R19' and b.code = 'R12';
insert into hunt_keys (card_id, answer) select a.id, k.answer from hunt_cards a, hunt_cards b join hunt_keys k on k.card_id = b.id
  where a.code = 'R19' and b.code = 'R12' on conflict (card_id) do update set answer = excluded.answer;
insert into hunt_cards (code, position, kind, prompt, options, letter_index, team_id, holder, grp, points, golden)
  select 'B19', 319, kind, prompt, options, letter_index, team_id, 'Ali Audi', grp, points, false from hunt_cards where code = 'B12'
  on conflict (code) do nothing;
insert into hunt_keys (card_id, answer) select a.id, k.answer from hunt_cards a, hunt_cards b join hunt_keys k on k.card_id = b.id
  where a.code = 'B19' and b.code = 'B12' on conflict (card_id) do update set answer = excluded.answer;
update hunt_cards set letter_index = null, letter_index2 = null, grp = null, points = 0 where code in ('R12', 'B12');
select code, holder, grp, letter_index from hunt_cards where code in ('R12', 'B12', 'R19', 'B19') order by code;
