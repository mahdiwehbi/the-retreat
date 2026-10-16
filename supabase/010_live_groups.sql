-- WASH Retreat, part 10: every QR group is closed until its session.
-- Groups: badges (word race), rooms (room bonus), lake (WAP deck, field tasks), sap (site test).
-- The presenter opens a group when it reaches the session that uses it; the host can also
-- switch each group by hand. state.live lists the open groups.

alter table state add column if not exists live text[] not null default '{}';
update state set live = case when hunt_live then array['badges'] else '{}' end where id = 1;

alter table hunt_cards add column if not exists grp text;
update hunt_cards set grp = case
  when code ~ '^R\d+$' then 'badges'
  when code ~ '^H\d+$' then 'rooms'
  when kind in ('find', 'photo') or code ~ '^[WFG]\d+$' then 'lake'
  else grp end;

create or replace function host_set_state(p_pin text, p_patch jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare st state; a activities; k int;
begin
  perform _need_host(p_pin);
  select * into st from state where id = 1;
  if p_patch ? 'activity_id' then
    st.activity_id := nullif(p_patch->>'activity_id', '')::uuid;
    st.phase := 'idle';
    st.opened_at := null;
    st.revealed_correct := null;
  end if;
  if p_patch ? 'phase' then
    st.phase := p_patch->>'phase';
    if st.phase = 'open' then
      st.opened_at := now();
      st.revealed_correct := null;
    end if;
    if st.phase = 'reveal' and st.activity_id is not null then
      select * into a from activities where id = st.activity_id;
      if a.kind = 'quiz' then
        select correct into k from activity_keys where activity_id = a.id;
        st.revealed_correct := k;
        update responses r set
          correct = (k is not null and (r.value->>'choice')::int = k),
          points = case when k is not null and (r.value->>'choice')::int = k
                        then round(500 + 500 * greatest(0, 1 - r.elapsed_ms / (greatest(a.time_limit, 1) * 1000.0)))::int
                        else 0 end
          where r.activity_id = a.id;
      end if;
    end if;
  end if;
  if p_patch ? 'screen' then st.screen := p_patch->>'screen'; end if;
  if p_patch ? 'session' then st.session_key := nullif(p_patch->>'session', ''); end if;
  if p_patch ? 'live' then
    st.live := array(select x from jsonb_array_elements_text(p_patch->'live') as x);
    st.hunt_live := 'badges' = any(st.live);
  end if;
  if p_patch ? 'hunt_live' then st.hunt_live := coalesce((p_patch->>'hunt_live')::boolean, false); end if;
  if p_patch ? 'podium_step' then st.podium_step := greatest(0, least(3, (p_patch->>'podium_step')::int)); end if;
  update state set activity_id = st.activity_id, phase = st.phase, screen = st.screen,
    opened_at = st.opened_at, revealed_correct = st.revealed_correct,
    podium_step = st.podium_step, session_key = st.session_key, hunt_live = st.hunt_live, live = st.live, updated_at = now()
    where id = 1;
end $$;

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
  if c.grp is not null and not (c.grp = any(coalesce((select live from state where id = 1), '{}'))) then
    raise exception '%', case c.grp when 'badges' then 'The word race has not started yet. Keep your badge!'
      when 'rooms' then 'Your room bonus opens at check-in.' when 'lake' then 'This opens at the lake.' else 'This is not open yet.' end;
  end if;
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

grant execute on function host_set_state(text, jsonb), hunt_submit(uuid, uuid, text, text, text) to anon, authenticated;

-- A name badge is also the way in: scanning it joins its owner in the team on the badge.
-- One badge = one player, so scanning again (or on a new phone) returns the same player.
alter table participants add column if not exists badge_code text unique;

create or replace function badge_checkin(p_code text) returns json
language plpgsql security definer set search_path = public as $$
declare c hunt_cards; p participants; v_tok uuid;
begin
  select * into c from hunt_cards where upper(code) = upper(btrim(coalesce(p_code, ''))) and coalesce(btrim(holder), '') <> '' and team_id is not null;
  if not found then raise exception 'This is not a name badge'; end if;
  select * into p from participants where badge_code = c.code;
  if not found then
    insert into participants (name, team_id, badge_code) values (left(btrim(c.holder), 40), c.team_id, c.code) returning * into p;
    insert into participant_tokens (participant_id) values (p.id) returning token into v_tok;
  else
    select token into v_tok from participant_tokens where participant_id = p.id;
    if v_tok is null then insert into participant_tokens (participant_id) values (p.id) returning token into v_tok; end if;
  end if;
  return json_build_object('id', p.id, 'token', v_tok, 'team_id', p.team_id, 'name', p.name);
end $$;
grant execute on function badge_checkin(text) to anon, authenticated;

-- Lake theme: team names.
update teams set name = case id when 1 then 'Herons' when 2 then 'Kingfishers' when 3 then 'Flamingos' else name end;
