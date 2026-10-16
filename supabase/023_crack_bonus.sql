-- WASH Retreat, part 23: cracking the message early pays: every question the team did not finish counts 4 points.

create or replace function hunt_guess(p_pid uuid, p_token uuid, p_guess text) returns json
language plpgsql security definer set search_path = public as $$
declare me participants; v_secret text; v_g text; ok boolean; v_used int; v_first boolean; v_open int;
begin
  me := _player(p_pid, p_token);
  select value into v_secret from secrets where key = 'hunt_secret';
  v_g := upper(regexp_replace(coalesce(p_guess, ''), '[^A-Za-z]', '', 'g'));
  if v_g = '' then raise exception 'Type your guess first'; end if;
  if exists (select 1 from hunt_guesses where team_id = me.team_id and correct) then
    return json_build_object('status', 'already');
  end if;
  select count(*) into v_used from hunt_guesses where team_id = me.team_id;
  if v_used >= 5 then return json_build_object('status', 'out'); end if;
  ok := v_g = upper(coalesce(v_secret, ''));
  v_first := ok and not exists (select 1 from hunt_guesses where correct);
  insert into hunt_guesses (team_id, participant_id, guess, correct) values (me.team_id, me.id, left(p_guess, 80), ok);
  if ok then
    -- Questions the team never finished count 4 points each when they crack the message.
    select count(*) into v_open from hunt_cards c where c.team_id = me.team_id and c.letter_index is not null
      and not exists (select 1 from hunt_finds x where x.card_id = c.id and x.team_id = me.team_id and x.correct)
      and (select count(*) from hunt_finds x where x.card_id = c.id and x.team_id = me.team_id and not x.correct) < 3;
    if v_open > 0 then insert into team_points (team_id, points, reason) values (me.team_id, 4 * v_open, 'Word race questions not needed (' || v_open || ' × 4)'); end if;
  end if;
  if v_first then
    insert into team_points (team_id, points, reason) values (me.team_id, 10, 'First to crack the secret word');
  elsif ok then
    insert into team_points (team_id, points, reason) values (me.team_id, 5, 'Cracked the secret word');
  end if;
  return json_build_object('status', case when ok then 'correct' else 'wrong' end, 'first', v_first, 'left', 4 - v_used);
end $$;

create or replace function hunt_submit(p_pid uuid, p_token uuid, p_code text, p_answer text, p_photo text default null) returns json
language plpgsql security definer set search_path = public as $$
declare me participants; c hunt_cards; k text; ok boolean; v_wrong int; v_secret text; v_letter text; sk hunt_spot_keys; v_pts int;
begin
  me := _player(p_pid, p_token);
  select * into c from hunt_cards where upper(code) = upper(btrim(coalesce(p_code, '')));
  if not found then raise exception 'This card is not part of the game'; end if;
  if c.team_id is not null and c.team_id <> me.team_id then
    raise exception 'This card belongs to %. Give it back to %.', (select name from teams where id = c.team_id), coalesce(nullif(btrim(c.holder), ''), 'its owner');
  end if;
  if c.grp = 'golden' then
    if not (exists (select 1 from sap_sites where team_id = me.team_id)
        and (select count(*) from sap_households h join sap_tents t on t.id = h.tent_id where h.team_id = me.team_id and t.number > 0) >= 3) then
      raise exception 'The golden card opens when your team has sent the site form and the 3 tents.';
    end if;
  elsif c.grp is not null and not (c.grp = any(coalesce((select live from state where id = 1), '{}'))) then
    raise exception '%', case c.grp when 'badges' then 'Your question opens at lunch. Keep your badge!' when 'rooms' then 'Your room question opens at check-in.' else 'This is not open yet.' end;
  end if;
  select value into v_secret from secrets where key = 'hunt_secret';
  if c.letter_index is not null and exists (select 1 from hunt_guesses where team_id = me.team_id and correct) then
    return json_build_object('status', 'already', 'letter', substr(coalesce(v_secret, ''), c.letter_index + 1, 1), 'note', 'Your team already cracked the message.');
  end if;
  if c.letter_index >= 0 and c.letter_index < char_length(coalesce(v_secret, '')) then v_letter := substr(v_secret, c.letter_index + 1, 1); end if;
  select count(*) into v_wrong from hunt_finds where card_id = c.id and team_id = me.team_id and not correct;
  if exists (select 1 from hunt_finds where card_id = c.id and team_id = me.team_id and correct) then
    return json_build_object('status', 'already', 'letter', v_letter);
  end if;
  if v_wrong >= 3 then return json_build_object('status', 'locked', 'letter', v_letter); end if;
  select answer into k from hunt_keys where card_id = c.id;
  k := coalesce(k, '');
  if c.kind = 'photo' then ok := coalesce(p_photo, '') <> '';
  elsif btrim(k) = '' then ok := btrim(coalesce(p_answer, '')) <> '';
  elsif c.kind = 'quiz' then ok := btrim(coalesce(p_answer, '')) = btrim(k);
  else ok := exists (select 1 from unnest(string_to_array(k, '|')) as a(x) where lower(btrim(x)) = lower(btrim(coalesce(p_answer, ''))));
  end if;
  insert into hunt_finds (card_id, team_id, participant_id, answer, photo, correct) values (c.id, me.team_id, me.id, left(p_answer, 300), left(p_photo, 500), ok);
  if ok then
    v_pts := 3 - v_wrong;
    if c.letter_index is not null and v_pts > 0 then
      insert into team_points (team_id, points, reason) values (me.team_id, v_pts, 'Word race question ' || c.code);
    end if;
    return json_build_object('status', 'correct', 'letter', v_letter, 'points', case when c.letter_index is null then c.points else v_pts end);
  end if;
  if v_wrong + 1 >= 3 then return json_build_object('status', 'locked', 'letter', v_letter, 'left', 0); end if;
  return json_build_object('status', 'wrong', 'left', 2 - v_wrong);
end $$;

create or replace function race_result() returns json
language plpgsql stable security definer set search_path = public as $$
declare st state;
begin
  select * into st from state where id = 1;
  if coalesce(st.present->>'race', '') <> 'reveal' then return null; end if;
  return json_build_object(
    'word', (select value from secrets where key = 'hunt_secret'),
    'teams', (select coalesce(json_agg(json_build_object('team_id', t.id,
        'questions', coalesce((select sum(points) from team_points p where p.team_id = t.id and (p.reason like 'Word race question%' or p.reason like 'Word race questions not needed%')), 0),
        'helps', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason like 'Word race help%'), 0),
        'crack', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason in ('First to crack the secret word', 'Cracked the secret word')), 0)
      ) order by t.id), '[]'::json) from teams t));
end $$;
grant execute on function race_result() to anon, authenticated;

grant execute on function hunt_guess(uuid, uuid, text), hunt_submit(uuid, uuid, text, text, text) to anon, authenticated;
