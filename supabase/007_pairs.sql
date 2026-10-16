-- WASH Retreat, part 7: the Day 1 word race with a 12-letter word and one card per person.
-- Each team gets its own 6 cards (one per person), and each card carries 2 letters, so every
-- team can build the whole word on its own. The first team to guess it wins.
-- Word: WASH TOGETHER. Person k of a team gets letters k and k+6 (W+G, A+E, S+T, H+H, T+E, O+R).

alter table hunt_cards add column if not exists letter_index2 int;
alter table hunt_cards add column if not exists team_id int references teams(id);
alter table hunt_cards add column if not exists holder text not null default '';

insert into secrets (key, value) values ('hunt_secret', 'WASHTOGETHER') on conflict (key) do update set value = excluded.value;
insert into secrets (key, value) values ('hunt_pattern', '4,8') on conflict (key) do update set value = excluded.value;

-- 18 person cards: R01–R06 Team 1, R07–R12 Team 2, R13–R18 Team 3.
do $$
declare v uuid;
begin
  if not exists (select 1 from hunt_cards where code = 'R18') then
    insert into hunt_cards (code, position, kind, prompt, options, points, golden)
      values ('R18', 18, 'quiz', 'In WAP, a tank shared by two families is counted…', '["For one family only", "For both families", "Not counted", "As a community tank"]'::jsonb, 1, false)
      returning id into v;
    insert into hunt_keys (card_id, answer) values (v, '0');
  end if;
end $$;

update hunt_cards c set
  team_id = (n - 1) / 6 + 1,
  letter_index = (n - 1) % 6,
  letter_index2 = (n - 1) % 6 + 6
from (select id, substr(code, 2)::int as n from hunt_cards where code ~ '^R\d+$') x
where c.id = x.id and x.n between 1 and 18;

-- Old room-card answers no longer match the new letters.
delete from hunt_finds f using hunt_cards c where c.id = f.card_id and c.code ~ '^R\d+$';

-- A card only works for its own team, and a right answer gives both letters.
create or replace function hunt_submit(p_pid uuid, p_token uuid, p_code text, p_answer text, p_photo text default null) returns json
language plpgsql security definer set search_path = public as $$
declare
  me participants; c hunt_cards; k text; ok boolean; v_wrong int; v_secret text; v_letter text; v_letter2 text; sk hunt_spot_keys; v_room boolean;
begin
  me := _player(p_pid, p_token);
  select * into c from hunt_cards where upper(code) = upper(btrim(coalesce(p_code, '')));
  if not found then raise exception 'This card is not part of the game'; end if;
  if c.team_id is not null and c.team_id <> me.team_id then
    raise exception 'This card belongs to %. Give it back to %.', (select name from teams where id = c.team_id),
      coalesce(nullif(btrim(c.holder), ''), 'its owner');
  end if;
  v_room := c.letter_index is not null;
  select value into v_secret from secrets where key = 'hunt_secret';
  v_secret := coalesce(v_secret, '');
  if c.letter_index >= 0 and c.letter_index < char_length(v_secret) then v_letter := substr(v_secret, c.letter_index + 1, 1); end if;
  if c.letter_index2 >= 0 and c.letter_index2 < char_length(v_secret) then v_letter2 := substr(v_secret, c.letter_index2 + 1, 1); end if;
  if c.kind = 'find' then select * into sk from hunt_spot_keys where code = upper(btrim(coalesce(p_answer, ''))); end if;
  if exists (select 1 from hunt_finds where card_id = c.id and team_id = me.team_id and correct) then
    return json_build_object('status', 'already', 'letter', v_letter, 'position', c.letter_index, 'letter2', v_letter2, 'position2', c.letter_index2, 'name', sk.name, 'explain', sk.explain);
  end if;
  select count(*) into v_wrong from hunt_finds where card_id = c.id and team_id = me.team_id and not correct;
  if v_wrong >= 3 and not v_room then return json_build_object('status', 'locked'); end if;
  select answer into k from hunt_keys where card_id = c.id;
  k := coalesce(k, '');
  if c.kind = 'photo' then ok := coalesce(p_photo, '') <> '';
  elsif btrim(k) = '' then ok := btrim(coalesce(p_answer, '')) <> '';
  elsif c.kind = 'quiz' then ok := btrim(coalesce(p_answer, '')) = btrim(k);
  else ok := exists (select 1 from unnest(string_to_array(k, '|')) as a(x) where lower(btrim(x)) = lower(btrim(coalesce(p_answer, ''))));
  end if;
  begin
    insert into hunt_finds (card_id, team_id, participant_id, answer, photo, correct)
      values (c.id, me.team_id, me.id, left(p_answer, 300), left(p_photo, 500), ok);
  exception when unique_violation then
    return json_build_object('status', 'already', 'letter', v_letter, 'position', c.letter_index, 'letter2', v_letter2, 'position2', c.letter_index2);
  end;
  if ok then return json_build_object('status', 'correct', 'letter', v_letter, 'position', c.letter_index, 'letter2', v_letter2, 'position2', c.letter_index2, 'points', c.points, 'name', sk.name, 'explain', sk.explain); end if;
  return json_build_object('status', 'wrong', 'left', case when v_room then 99 else 2 - v_wrong end, 'name', sk.name, 'explain', sk.explain);
end $$;

create or replace function hunt_my_team(p_pid uuid, p_token uuid) returns json
language plpgsql stable security definer set search_path = public as $$
declare me participants; v_secret text;
begin
  me := _player(p_pid, p_token);
  select coalesce(value, '') into v_secret from secrets where key = 'hunt_secret';
  return (select coalesce(json_agg(json_build_object(
      'id', c.id, 'code', c.code, 'solved', x.solved,
      'wrong', (select count(*) from hunt_finds f where f.card_id = c.id and f.team_id = me.team_id and not f.correct),
      'letter', case when x.solved and c.letter_index < char_length(v_secret) then substr(v_secret, c.letter_index + 1, 1) end,
      'letter2', case when x.solved and c.letter_index2 < char_length(v_secret) then substr(v_secret, c.letter_index2 + 1, 1) end
    ) order by c.position, c.code), '[]'::json)
    from hunt_cards c
    cross join lateral (select exists (select 1 from hunt_finds f where f.card_id = c.id and f.team_id = me.team_id and f.correct) as solved) x
    where c.team_id is null or c.team_id = me.team_id);
end $$;

create or replace function hunt_board() returns json
language plpgsql stable security definer set search_path = public as $$
declare v_secret text; v_pattern text;
begin
  select value into v_secret from secrets where key = 'hunt_secret';
  select value into v_pattern from secrets where key = 'hunt_pattern';
  v_secret := coalesce(v_secret, '');
  return json_build_object(
    'length', char_length(v_secret),
    'pattern', coalesce(v_pattern, ''),
    'cards', (select count(*) from hunt_cards where letter_index is not null),
    'winner', (select team_id from hunt_guesses where correct order by created_at limit 1),
    'solved_teams', (select coalesce(json_agg(team_id order by created_at), '[]'::json) from hunt_guesses where correct),
    'teams', (select coalesce(json_agg(json_build_object(
      'team_id', t.id,
      'cards', (select count(*) from hunt_cards c where c.team_id = t.id and c.letter_index is not null),
      'found', (select count(*) from hunt_finds f join hunt_cards c on c.id = f.card_id where f.team_id = t.id and f.correct and c.letter_index is not null),
      'letters', (select coalesce(sum((c.letter_index is not null)::int + (c.letter_index2 is not null)::int), 0) from hunt_finds f join hunt_cards c on c.id = f.card_id where f.team_id = t.id and f.correct),
      'guesses', (select count(*) from hunt_guesses g where g.team_id = t.id)
    ) order by t.id), '[]'::json) from teams t)
  );
end $$;

-- Saving the word with spaces ("WASH TOGETHER") also saves the blank pattern.
create or replace function host_set_secret(p_pin text, p_word text) returns void
language plpgsql security definer set search_path = public as $$
declare v_words text[];
begin
  perform _need_host(p_pin);
  insert into secrets (key, value) values ('hunt_secret', upper(regexp_replace(coalesce(p_word, ''), '[^A-Za-z]', '', 'g')))
    on conflict (key) do update set value = excluded.value;
  v_words := array(select w from regexp_split_to_table(btrim(upper(regexp_replace(coalesce(p_word, ''), '[^A-Za-z ]', '', 'g'))), '\s+') as w where w <> '');
  insert into secrets (key, value) values ('hunt_pattern', array_to_string(array(select char_length(w)::text from unnest(v_words) as w), ','))
    on conflict (key) do update set value = excluded.value;
end $$;

create or replace function host_save_card(p_pin text, p_id uuid, p_data jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid := p_id;
begin
  perform _need_host(p_pin);
  if v_id is null then
    insert into hunt_cards (code, position, kind, prompt, options, letter_index, letter_index2, team_id, holder, points, golden) values (
      upper(coalesce(nullif(btrim(p_data->>'code'), ''), substr(md5(random()::text), 1, 5))),
      coalesce((p_data->>'position')::int, (select coalesce(max(position), 0) + 1 from hunt_cards)),
      coalesce(p_data->>'kind', 'text'), coalesce(p_data->>'prompt', ''),
      coalesce(p_data->'options', '[]'::jsonb), nullif(p_data->>'letter_index', '')::int, nullif(p_data->>'letter_index2', '')::int,
      nullif(p_data->>'team_id', '')::int, left(coalesce(p_data->>'holder', ''), 60),
      coalesce((p_data->>'points')::int, 1), coalesce((p_data->>'golden')::boolean, false))
    returning id into v_id;
  else
    update hunt_cards set
      code = upper(coalesce(nullif(btrim(p_data->>'code'), ''), code)),
      position = coalesce((p_data->>'position')::int, position),
      kind = coalesce(p_data->>'kind', kind),
      prompt = coalesce(p_data->>'prompt', prompt),
      options = coalesce(p_data->'options', options),
      letter_index = case when p_data ? 'letter_index' then nullif(p_data->>'letter_index', '')::int else letter_index end,
      letter_index2 = case when p_data ? 'letter_index2' then nullif(p_data->>'letter_index2', '')::int else letter_index2 end,
      team_id = case when p_data ? 'team_id' then nullif(p_data->>'team_id', '')::int else team_id end,
      holder = case when p_data ? 'holder' then left(coalesce(p_data->>'holder', ''), 60) else holder end,
      points = coalesce((p_data->>'points')::int, points),
      golden = coalesce((p_data->>'golden')::boolean, golden)
    where id = v_id;
  end if;
  if p_data ? 'answer' then
    insert into hunt_keys (card_id, answer) values (v_id, coalesce(p_data->>'answer', ''))
      on conflict (card_id) do update set answer = excluded.answer;
  end if;
  return v_id;
end $$;

grant execute on function hunt_submit(uuid, uuid, text, text, text), hunt_my_team(uuid, uuid), hunt_board(),
  host_set_secret(text, text), host_save_card(text, uuid, jsonb) to anon, authenticated;
