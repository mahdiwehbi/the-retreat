-- WASH Retreat, part 25: each wrong guess of the message costs 1 point.

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
  if not ok then insert into team_points (team_id, points, reason) values (me.team_id, -1, 'Word race wrong guess'); end if;
  if v_first then
    insert into team_points (team_id, points, reason) values (me.team_id, 10, 'First to crack the secret word');
  elsif ok then
    insert into team_points (team_id, points, reason) values (me.team_id, 5, 'Cracked the secret word');
  end if;
  return json_build_object('status', case when ok then 'correct' else 'wrong' end, 'first', v_first, 'left', 4 - v_used);
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
        'questions', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason like 'Word race question %'), 0),
        'bonus', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason like 'Word race questions not needed%'), 0),
        'wrong', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason = 'Word race wrong guess'), 0),
        'helps', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason like 'Word race help%'), 0),
        'crack', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason in ('First to crack the secret word', 'Cracked the secret word')), 0)
      ) order by t.id), '[]'::json) from teams t));
end $$;

-- Backfill for the test run so far: -1 per wrong guess, and the 4-point bonus for teams that cracked it before the bonus existed.
insert into team_points (team_id, points, reason)
  select g.team_id, -1, 'Word race wrong guess' from hunt_guesses g where not g.correct
    and (select count(*) from team_points p where p.team_id = g.team_id and p.reason = 'Word race wrong guess') < (select count(*) from hunt_guesses x where x.team_id = g.team_id and not x.correct);
insert into team_points (team_id, points, reason)
  select t.id, 4 * n.k, 'Word race questions not needed (' || n.k || ' × 4)'
  from teams t cross join lateral (select count(*) as k from hunt_cards c where c.team_id = t.id and c.letter_index is not null
      and not exists (select 1 from hunt_finds x where x.card_id = c.id and x.team_id = t.id and x.correct)
      and (select count(*) from hunt_finds x where x.card_id = c.id and x.team_id = t.id and not x.correct) < 3) n
  where exists (select 1 from hunt_guesses g where g.team_id = t.id and g.correct)
    and not exists (select 1 from team_points p where p.team_id = t.id and p.reason like 'Word race questions not needed%')
    and n.k > 0;

grant execute on function hunt_guess(uuid, uuid, text), race_result() to anon, authenticated;
