-- WASH Retreat, part 11: registration is a QR group too.
-- 'register' is open at the welcome (join screen and The Source); moving on to Upstream closes it.
-- Already checked-in badges keep working (re-login on a new phone); new joins need it open.
-- Real sticky notes on Day 1, so the phone sticky-note wall and dot vote go.

create or replace function join_retreat(p_name text, p_team int default null) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid; v_tok uuid; v_team int;
  v_name text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
begin
  if char_length(v_name) < 1 or char_length(v_name) > 40 then
    raise exception 'Please enter your name (up to 40 letters)';
  end if;
  if not ('register' = any(coalesce((select live from state where id = 1), '{}'))) then
    raise exception 'Registration is closed. Please see the facilitator.';
  end if;
  if (select count(*) from participants) >= 120 then
    raise exception 'The game is full. Ask the facilitator.';
  end if;
  if p_team is not null and exists (select 1 from teams where id = p_team) then
    v_team := p_team;
  else
    select t.id into v_team from teams t left join participants p on p.team_id = t.id
      group by t.id order by count(p.id), t.id limit 1;
  end if;
  insert into participants (name, team_id) values (v_name, v_team) returning id into v_id;
  insert into participant_tokens (participant_id) values (v_id) returning token into v_tok;
  return json_build_object('id', v_id, 'token', v_tok, 'team_id', v_team, 'name', v_name);
end $$;

create or replace function badge_checkin(p_code text) returns json
language plpgsql security definer set search_path = public as $$
declare c hunt_cards; p participants; v_tok uuid;
begin
  select * into c from hunt_cards where upper(code) = upper(btrim(coalesce(p_code, ''))) and coalesce(btrim(holder), '') <> '' and team_id is not null;
  if not found then raise exception 'This is not a name badge'; end if;
  select * into p from participants where badge_code = c.code;
  if not found then
    if not ('register' = any(coalesce((select live from state where id = 1), '{}'))) then
      raise exception 'Registration is closed. Please see the facilitator.';
    end if;
    insert into participants (name, team_id, badge_code) values (left(btrim(c.holder), 40), c.team_id, c.code) returning * into p;
    insert into participant_tokens (participant_id) values (p.id) returning token into v_tok;
  else
    select token into v_tok from participant_tokens where participant_id = p.id;
    if v_tok is null then insert into participant_tokens (participant_id) values (p.id) returning token into v_tok; end if;
  end if;
  return json_build_object('id', p.id, 'token', v_tok, 'team_id', p.team_id, 'name', p.name);
end $$;

delete from activities where kind in ('board', 'dots');
update state set live = array_append(live, 'register') where id = 1 and not ('register' = any(live));

grant execute on function join_retreat(text, int), badge_checkin(text) to anon, authenticated;
