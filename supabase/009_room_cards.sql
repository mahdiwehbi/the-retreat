-- WASH Retreat, part 9: room welcome cards.
-- One named card on each overnight guest's bed: a welcome, the evening plan and a QR code
-- to a bonus WAP question (2 points for their team, 3 tries). Works any time, not part of the word.

do $$
declare v uuid;
begin
  if not exists (select 1 from hunt_cards where code = 'H01') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H01', 201, 'quiz', 'Room bonus: A sealed tank with no outlet, emptied by truck. In WAP it is a…', '["Septic tank", "Holding tank", "Cesspit", "Covered pit"]'::jsonb, 2, false, 1, 'Joseph Hanna') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '1');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H02') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H02', 202, 'quiz', 'Room bonus: A pit with lined sides and a cover, but an open base, is a…', '["Cesspit", "Holding tank", "Uncovered pit", "Septic tank"]'::jsonb, 2, false, 1, 'Ibrahim El Jisr') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '0');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H03') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H03', 203, 'quiz', 'Room bonus: A borehole with a concrete slab but no cap or seal is…', '["Protected", "Unprotected", "A spring", "Not counted"]'::jsonb, 2, false, 1, 'Ahmad Hammoud') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '1');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H04') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H04', 204, 'quiz', 'Room bonus: A spring box with no fence and no drainage is a…', '["Protected spring", "Unprotected spring", "Public network", "Borehole"]'::jsonb, 2, false, 1, 'Houssein Hamdan') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '1');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H05') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H05', 205, 'quiz', 'Room bonus: A latrine made of plastic sheeting on a frame is…', '["Improved and usable", "Not improved", "Not usable", "Not counted"]'::jsonb, 2, false, 1, 'Ahmad Mostafa') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '1');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H06') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H06', 206, 'quiz', 'Room bonus: In WAP, elderly means…', '["55 or older", "60 or older", "65 or older", "70 or older"]'::jsonb, 2, false, 2, 'Joe Antoun') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '1');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H07') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H07', 207, 'quiz', 'Room bonus: One barrel counts as…', '["100 L", "150 L", "200 L", "500 L"]'::jsonb, 2, false, 2, 'Nicole Moussa') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '2');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H08') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H08', 208, 'quiz', 'Room bonus: Do 20 L jerrycans count as storage tanks?', '["Yes, all of them", "Only if full", "No", "Only if shared"]'::jsonb, 2, false, 2, 'Ali Sous') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '2');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H09') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H09', 209, 'quiz', 'Room bonus: A tank shared by two families is counted…', '["For both families", "For one family only", "As community storage", "Not at all"]'::jsonb, 2, false, 2, 'James Henderson') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '1');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H10') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H10', 210, 'quiz', 'Room bonus: A household member who is exactly 18 is…', '["A child", "An adult", "Elderly", "Not counted"]'::jsonb, 2, false, 2, 'Khaled Houchaimi') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '1');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H11') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H11', 211, 'quiz', 'Room bonus: A latrine that needs maintenance, not rehabilitation, is…', '["Improved and usable", "Not improved", "Not usable", "Blocked"]'::jsonb, 2, false, 3, 'Georges Bsaibes') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '0');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H12') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H12', 212, 'quiz', 'Room bonus: A septic tank is…', '["Full treatment", "Pre-treatment", "A holding tank", "A public network"]'::jsonb, 2, false, 3, 'Rawad Amine') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '1');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H13') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H13', 213, 'quiz', 'Room bonus: Water trucking paid by an NGO and by occupants are…', '["The same option", "Separate options", "Not water sources", "Counted as network"]'::jsonb, 2, false, 3, 'Lama Jida') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '1');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H14') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H14', 214, 'quiz', 'Room bonus: The main water source is the one that…', '["Is closest", "Is cheapest", "Gives the greatest quantity", "Is protected"]'::jsonb, 2, false, 3, 'Salam Ramdan') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '2');
  end if;
  if not exists (select 1 from hunt_cards where code = 'H15') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden, team_id, holder) values ('H15', 215, 'quiz', 'Room bonus: How many critical times for handwashing does the KAP ask about?', '["3", "4", "5", "7"]'::jsonb, 2, false, 3, 'Abdulrahman Ali') returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '2');
  end if;
end $$;
