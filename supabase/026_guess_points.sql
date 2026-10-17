-- WASH Retreat, part 26: the guess scores like a question: 3 / 2 / 1 on the 1st / 2nd / 3rd try (no more -1 per wrong guess).

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
  if ok and v_used < 3 then insert into team_points (team_id, points, reason) values (me.team_id, 3 - v_used, 'Word race guess on try ' || (v_used + 1)); end if;
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
        'guess', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason like 'Word race guess on try%'), 0),
        'helps', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason like 'Word race help%'), 0),
        'crack', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason in ('First to crack the secret word', 'Cracked the secret word')), 0)
      ) order by t.id), '[]'::json) from teams t));
end $$;

-- Replace the old -1 per wrong guess with points for the guess: 3 on the 1st try, 2 on the 2nd, 1 on the 3rd.
delete from team_points where reason = 'Word race wrong guess';
insert into team_points (team_id, points, reason)
  select g.team_id, 3 - (select count(*) from hunt_guesses x where x.team_id = g.team_id and x.created_at < g.created_at), 'Word race guess on try ' || (1 + (select count(*) from hunt_guesses x where x.team_id = g.team_id and x.created_at < g.created_at))
  from hunt_guesses g where g.correct
    and (select count(*) from hunt_guesses x where x.team_id = g.team_id and x.created_at < g.created_at) < 3
    and not exists (select 1 from team_points p where p.team_id = g.team_id and p.reason like 'Word race guess on try%');

grant execute on function hunt_guess(uuid, uuid, text), race_result() to anon, authenticated;
