-- WASH Retreat, part 16: a badge for Ali Audi (both days, no room). Kingfishers.
-- His badge carries the same 2 letters as R07 (W and G): a backup for his team, not new letters.
do $$
declare v uuid;
begin
  if not exists (select 1 from hunt_cards where code = 'R19') then
    insert into hunt_cards (code, position, kind, prompt, options, letter_index, letter_index2, team_id, holder, grp, points, golden)
      values ('R19', 19, 'quiz', 'In WAP, a child is anyone who is…', '["Under 15", "Under 16", "Under 18", "Under 21"]'::jsonb, 0, 6, 2, 'Ali Audi', 'badges', 1, false)
      returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '2');
  end if;
end $$;
