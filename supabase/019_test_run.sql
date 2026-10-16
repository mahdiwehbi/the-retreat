-- WASH Retreat, part 19: everything from the test run.

-- 1) Activities: simpler sessions, no scoring where nothing is right or wrong, no Day 2 screen.
delete from responses where activity_id in (select id from activities where position in (6, 26, 28, 30, 31, 33, 34, 35, 36, 37, 38, 39, 40, 41));
delete from team_entries where activity_id in (select id from activities where position in (6, 26, 28, 30, 31, 33, 34, 35, 36, 37, 38, 39, 40, 41));
delete from activities where position in (6, 26, 28, 30, 31, 33, 34, 35, 36, 37, 38, 39, 40, 41);
update activities set title = 'Personal reflection: one lesson from the war I will never forget' where position = 8;
update activities set title = 'IM tools speed-dating: love, pain, wish', options = '{"fields": [{"type": "list", "label": "War sheet (booking)", "tags": ["Love", "Pain", "Wish"]}, {"type": "list", "label": "Referral sheet", "tags": ["Love", "Pain", "Wish"]}, {"type": "list", "label": "ActivityInfo", "tags": ["Love", "Pain", "Wish"]}, {"type": "list", "label": "RTA (rapid technical assessment)", "tags": ["Love", "Pain", "Wish"]}, {"type": "list", "label": "QR tracking", "tags": ["Love", "Pain", "Wish"]}]}'::jsonb where position = 19;
update activities set title = 'War sheet (booking): keep, fix or kill?' where position = 20;
update activities set title = 'Referral sheet: keep, fix or kill?' where position = 21;
update activities set title = 'ActivityInfo: keep, fix or kill?' where position = 22;
update activities set title = 'RTA (rapid technical assessment): keep, fix or kill?' where position = 23;
update activities set title = 'QR tracking: keep, fix or kill?' where position = 24;
update activities set title = 'Murky Waters: problems and suggestions', options = '{"fields": [{"type": "text", "label": "Problems we found"}, {"type": "text", "label": "Suggestions: what a future referral tool should do"}]}'::jsonb where position = 25;
update activities set title = 'What if? Our plan for the scenario', options = jsonb_build_object('fields', '[{"type": "text", "label": "Who coordinates what"}, {"type": "text", "label": "IM tools we need"}, {"type": "text", "label": "Lessons from this morning we apply"}]'::jsonb, 'prompts', options->'prompts') where position = 27;
update activities set title = 'Informal settlements: where does the sector stand today?' where position = 29;
insert into activities (position, kind, title, options) select 30, 'open', 'Informal settlements: what do we need?', '[]'::jsonb where not exists (select 1 from activities where position = 30);

-- 2) Presenting: a random order wheel, one team per page.
alter table state add column if not exists present jsonb;
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
  if p_patch ? 'present' then st.present := case when jsonb_typeof(p_patch->'present') = 'null' then null else p_patch->'present' end; end if;
  if p_patch ? 'live' then
    st.live := array(select x from jsonb_array_elements_text(p_patch->'live') as x);
    st.hunt_live := 'badges' = any(st.live);
  end if;
  if p_patch ? 'hunt_live' then st.hunt_live := coalesce((p_patch->>'hunt_live')::boolean, false); end if;
  if p_patch ? 'podium_step' then st.podium_step := greatest(0, least(3, (p_patch->>'podium_step')::int)); end if;
  update state set activity_id = st.activity_id, phase = st.phase, screen = st.screen,
    opened_at = st.opened_at, revealed_correct = st.revealed_correct,
    podium_step = st.podium_step, session_key = st.session_key, hunt_live = st.hunt_live, live = st.live, present = st.present, updated_at = now()
    where id = 1;
end $$;

-- 3) Day 2 is the WAP assessment only: the lake clue game goes.
-- The golden card stays: a team photo, open once the team has sent the site form and its 3 tents.
update hunt_cards set grp = 'golden', kind = 'photo', points = 3, golden = true, team_id = null,
  prompt = 'Golden card: a photo of your whole team at the lake, with something WASH in the picture.' where code = 'G1';
delete from hunt_finds where card_id in (select id from hunt_cards where grp = 'lake');
delete from hunt_keys where card_id in (select id from hunt_cards where grp = 'lake');
delete from hunt_cards where grp = 'lake';

-- 4) Word race: 2 questions per person, 1 letter each, 3 tries, 3/2/1/0 points.
update hunt_cards c set holder = x.h from (values ('R01', 'Joseph Hanna'), ('R02', 'Ibrahim El Jisr'), ('R03', 'Ahmad Hammoud'), ('R04', 'Houssein Hamdan'), ('R05', 'Ahmad Mostafa'), ('R06', 'Michel Samaha'), ('R07', 'Joe Antoun'), ('R08', 'Nicole Moussa'), ('R09', 'Ali Sous'), ('R10', 'James Henderson'), ('R11', 'Khaled Houchaimi'), ('R12', 'Issa Wehbi'), ('R13', 'Georges Bsaibes'), ('R14', 'Rawad Amine'), ('R15', 'Lama Jida'), ('R16', 'Salam Ramdan'), ('R17', 'Abdulrahman Ali'), ('R18', 'Diana Mroueh')) as x(c, h) where c.code = x.c and coalesce(c.holder, '') = '';
update hunt_cards h set letter_index = r.letter_index2, team_id = r.team_id, points = 0, prompt = regexp_replace(h.prompt, '^Room bonus: ', '')
  from hunt_cards r where h.code ~ '^H\d+$' and r.code ~ '^R\d+$' and r.holder = h.holder and r.letter_index2 is not null;
do $$
declare v uuid;
begin
  if not exists (select 1 from hunt_cards where code = 'B06') then
    insert into hunt_cards (code, position, kind, prompt, options, letter_index, team_id, holder, grp, points, golden)
      select 'B06', 300 + 6, 'quiz', 'In WAP, a tank with holes drilled in its sides counts as a…', '["Holding tank", "Cesspit", "Septic tank", "Covered pit"]'::jsonb, r.letter_index2, r.team_id, r.holder, 'badges', 0, false from hunt_cards r where r.code ~ '^R\d+$' and r.holder = 'Michel Samaha' returning id into v;
    if v is not null then insert into hunt_keys (card_id, answer) values (v, '1'); end if;
  end if;
  if not exists (select 1 from hunt_cards where code = 'B12') then
    insert into hunt_cards (code, position, kind, prompt, options, letter_index, team_id, holder, grp, points, golden)
      select 'B12', 300 + 12, 'quiz', 'A borehole with a concrete slab but no cap is…', '["Protected", "Unprotected", "A spring", "Not counted"]'::jsonb, r.letter_index2, r.team_id, r.holder, 'badges', 0, false from hunt_cards r where r.code ~ '^R\d+$' and r.holder = 'Issa Wehbi' returning id into v;
    if v is not null then insert into hunt_keys (card_id, answer) values (v, '1'); end if;
  end if;
  if not exists (select 1 from hunt_cards where code = 'B18') then
    insert into hunt_cards (code, position, kind, prompt, options, letter_index, team_id, holder, grp, points, golden)
      select 'B18', 300 + 18, 'quiz', 'How many litres is "five barrels" of storage?', '["500 L", "750 L", "1,000 L", "2,000 L"]'::jsonb, r.letter_index2, r.team_id, r.holder, 'badges', 0, false from hunt_cards r where r.code ~ '^R\d+$' and r.holder = 'Diana Mroueh' returning id into v;
    if v is not null then insert into hunt_keys (card_id, answer) values (v, '2'); end if;
  end if;
  if not exists (select 1 from hunt_cards where code = 'B19') then
    insert into hunt_cards (code, position, kind, prompt, options, letter_index, team_id, holder, grp, points, golden)
      select 'B19', 300 + 19, 'quiz', 'A latrine made of plastic sheeting on a frame is…', '["Improved and usable", "Not improved", "Not usable", "Not counted"]'::jsonb, r.letter_index2, r.team_id, r.holder, 'badges', 0, false from hunt_cards r where r.code ~ '^R\d+$' and r.holder = 'Ali Audi' returning id into v;
    if v is not null then insert into hunt_keys (card_id, answer) values (v, '1'); end if;
  end if;
end $$;
update hunt_cards set letter_index2 = null, points = 0 where code ~ '^R\d+$';
delete from hunt_finds where card_id in (select id from hunt_cards where letter_index is not null);

create table if not exists race_board (
  team_id int not null references teams(id), slot int not null, code text not null, letter text not null,
  placed_by uuid references participants(id) on delete set null, locked boolean not null default false,
  primary key (team_id, slot));
alter table race_board enable row level security;
drop policy if exists "public read" on race_board; create policy "public read" on race_board for select using (true);
create table if not exists race_help (participant_id uuid primary key references participants(id) on delete cascade, team_id int, code text, at timestamptz default now());
alter table race_help enable row level security;
do $$ begin
  begin alter publication supabase_realtime add table race_board; exception when others then null; end;
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

-- The letters this person has opened (only theirs, not the team's).
create or replace function race_my_letters(p_pid uuid, p_token uuid) returns json
language plpgsql stable security definer set search_path = public as $$
declare me participants; v_secret text;
begin
  me := _player(p_pid, p_token);
  select coalesce(value, '') into v_secret from secrets where key = 'hunt_secret';
  return (select coalesce(json_agg(json_build_object('code', c.code, 'letter', substr(v_secret, c.letter_index + 1, 1), 'helped', exists (select 1 from race_help h where h.participant_id = me.id and h.code = c.code)) order by c.code), '[]'::json)
    from hunt_cards c
    where c.letter_index is not null and c.team_id = me.team_id and lower(btrim(c.holder)) = lower(btrim(me.name))
      and (exists (select 1 from hunt_finds f where f.card_id = c.id and f.team_id = me.team_id and f.correct)
        or (select count(*) from hunt_finds f where f.card_id = c.id and f.team_id = me.team_id and not f.correct) >= 3));
end $$;

create or replace function _race_owned(me participants, p_code text) returns hunt_cards
language plpgsql stable security definer set search_path = public as $$
declare c hunt_cards; v_secret text;
begin
  select * into c from hunt_cards where upper(code) = upper(btrim(coalesce(p_code, ''))) and letter_index is not null and team_id = me.team_id;
  if not found then raise exception 'This letter is not yours'; end if;
  if not (exists (select 1 from hunt_finds f where f.card_id = c.id and f.team_id = me.team_id and f.correct)
       or (select count(*) from hunt_finds f where f.card_id = c.id and f.team_id = me.team_id and not f.correct) >= 3) then
    raise exception 'Answer the question first to open this letter';
  end if;
  return c;
end $$;

create or replace function race_place(p_pid uuid, p_token uuid, p_code text, p_slot int) returns void
language plpgsql security definer set search_path = public as $$
declare me participants; c hunt_cards; v_secret text; v_len int;
begin
  me := _player(p_pid, p_token);
  if not ('race' = any(coalesce((select live from state where id = 1), '{}'))) then raise exception 'The word race has not started yet'; end if;
  c := _race_owned(me, p_code);
  select coalesce(value, '') into v_secret from secrets where key = 'hunt_secret'; v_len := char_length(v_secret);
  if p_slot < 0 or p_slot >= v_len then raise exception 'No such box'; end if;
  if exists (select 1 from race_board where team_id = me.team_id and slot = p_slot and locked) then raise exception 'That box is locked by a help'; end if;
  if exists (select 1 from race_board where team_id = me.team_id and code = c.code and locked) then raise exception 'That letter is locked in place'; end if;
  delete from race_board where team_id = me.team_id and code = c.code;
  insert into race_board (team_id, slot, code, letter, placed_by) values (me.team_id, p_slot, c.code, substr(v_secret, c.letter_index + 1, 1), me.id)
    on conflict (team_id, slot) do update set code = excluded.code, letter = excluded.letter, placed_by = excluded.placed_by, locked = false;
end $$;

create or replace function race_clear(p_pid uuid, p_token uuid, p_slot int) returns void
language plpgsql security definer set search_path = public as $$
declare me participants;
begin
  me := _player(p_pid, p_token);
  delete from race_board where team_id = me.team_id and slot = p_slot and not locked;
end $$;

-- One help per person: puts one of their letters in its right place, for 1 point.
create or replace function race_help_me(p_pid uuid, p_token uuid, p_code text) returns json
language plpgsql security definer set search_path = public as $$
declare me participants; c hunt_cards; v_secret text;
begin
  me := _player(p_pid, p_token);
  if not ('race' = any(coalesce((select live from state where id = 1), '{}'))) then raise exception 'The word race has not started yet'; end if;
  if exists (select 1 from race_help where participant_id = me.id) then raise exception 'You already used your help'; end if;
  c := _race_owned(me, p_code);
  select coalesce(value, '') into v_secret from secrets where key = 'hunt_secret';
  delete from race_board where team_id = me.team_id and (code = c.code or slot = c.letter_index);
  insert into race_board (team_id, slot, code, letter, placed_by, locked) values (me.team_id, c.letter_index, c.code, substr(v_secret, c.letter_index + 1, 1), me.id, true);
  insert into race_help (participant_id, team_id, code) values (me.id, me.team_id, c.code);
  insert into team_points (team_id, points, reason) values (me.team_id, -1, 'Word race help (' || me.name || ')');
  return json_build_object('slot', c.letter_index);
end $$;

create or replace function hunt_board() returns json
language plpgsql stable security definer set search_path = public as $$
declare v_secret text; v_pattern text;
begin
  select value into v_secret from secrets where key = 'hunt_secret';
  select value into v_pattern from secrets where key = 'hunt_pattern';
  v_secret := coalesce(v_secret, '');
  return json_build_object(
    'length', char_length(v_secret), 'pattern', coalesce(v_pattern, ''),
    'winner', (select team_id from hunt_guesses where correct order by created_at limit 1),
    'solved_teams', (select coalesce(json_agg(team_id order by created_at), '[]'::json) from hunt_guesses where correct),
    'teams', (select coalesce(json_agg(json_build_object(
      'team_id', t.id,
      'cards', (select count(*) from hunt_cards c where c.team_id = t.id and c.letter_index is not null),
      'opened', (select count(*) from hunt_cards c where c.team_id = t.id and c.letter_index is not null and (exists (select 1 from hunt_finds f where f.card_id = c.id and f.team_id = t.id and f.correct) or (select count(*) from hunt_finds f where f.card_id = c.id and f.team_id = t.id and not f.correct) >= 3)),
      'placed', (select count(*) from race_board b where b.team_id = t.id),
      'guesses', (select count(*) from hunt_guesses g where g.team_id = t.id)
    ) order by t.id), '[]'::json) from teams t));
end $$;

-- 5) Site test: 1 site and 3 tents per team (a sample of 3 of the 10 shelters); tent 4 becomes the practice tent.
delete from sap_households where tent_id in (select id from sap_tents where number > 4 or number = 0);
delete from sap_tents where number > 4;
update sap_tents set number = 0 where number = 4;
delete from sap_households where tent_id in (select id from sap_tents where number = 0);
create or replace function sap_summary(p_team int) returns json
language plpgsql stable security definer set search_path = public as $$
declare n_tents int; n_done int; site jsonb; hh jsonb;
begin
  select count(*) into n_tents from sap_tents where team_id = p_team and number > 0;
  select count(*) into n_done from sap_households h join sap_tents t on t.id = h.tent_id where h.team_id = p_team and t.number > 0;
  select data into site from sap_sites where team_id = p_team;
  select coalesce(jsonb_agg(h.data || jsonb_build_object('tent', t.number, 'kap', h.kap is not null, 'by', p.name, 'at', h.created_at, 'started', h.started_at) order by t.number), '[]'::jsonb)
    into hh from sap_households h join sap_tents t on t.id = h.tent_id left join participants p on p.id = h.participant_id
    where h.team_id = p_team and t.number > 0;
  return json_build_object('tents', n_tents, 'done', n_done, 'site', coalesce(site, '{}'::jsonb), 'households', hh,
    'site_by', (select p.name from sap_sites s left join participants p on p.id = s.participant_id where s.team_id = p_team),
    'site_at', (select updated_at from sap_sites where team_id = p_team),
    'first_start', (select min(x) from (select started_at x from sap_households where team_id = p_team union all select started_at from sap_sites where team_id = p_team) z));
end $$;

create or replace function host_sap_accuracy(p_pin text) returns json
language plpgsql stable security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  return (select coalesce(json_agg(json_build_object('team_id', tm.id, 'checked', x.checked, 'right', x.right_n) order by tm.id), '[]'::json)
    from teams tm left join lateral (
      select count(*) as checked, count(*) filter (where (coalesce(h.first_data, h.data)->>k.key) = (tr.data->>k.key)) as right_n
      from sap_households h join sap_truth tr on tr.tent_id = h.tent_id, jsonb_object_keys(tr.data) as k(key)
      where h.team_id = tm.id and h.tent_id in (select id from sap_tents where number > 0)
    ) x on true);
end $$;

-- 6) Feedback at the end of Day 2, no host needed.
create table if not exists feedback (participant_id uuid primary key references participants(id) on delete cascade, team_id int, data jsonb not null, created_at timestamptz not null default now());
alter table feedback enable row level security;
create or replace function submit_feedback(p_pid uuid, p_token uuid, p_data jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare me participants;
begin
  me := _player(p_pid, p_token);
  if length(coalesce(p_data, '{}'::jsonb)::text) > 6000 then raise exception 'Too long'; end if;
  insert into feedback (participant_id, team_id, data) values (me.id, me.team_id, coalesce(p_data, '{}'::jsonb))
    on conflict (participant_id) do update set data = excluded.data, created_at = now();
end $$;
create or replace function host_feedback(p_pin text) returns json
language plpgsql stable security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  return (select coalesce(json_agg(json_build_object('name', p.name, 'team_id', f.team_id, 'data', f.data, 'at', f.created_at) order by f.created_at), '[]'::json)
    from feedback f join participants p on p.id = f.participant_id);
end $$;

create or replace function host_reset(p_pin text, p_what text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  if p_what in ('answers', 'all') then
    delete from responses where true; delete from notes where true; delete from note_votes where true; delete from team_entries where true;
  end if;
  if p_what in ('points', 'all') then delete from team_points where true; end if;
  if p_what in ('hunt', 'all') then delete from hunt_finds where true; delete from hunt_guesses where true; delete from race_board where true; delete from race_help where true; end if;
  if p_what in ('checks', 'all') then
    delete from assessments where true; delete from feedback where true; delete from sap_households where true; delete from sap_sites where true;
  end if;
  if p_what in ('players', 'all') then delete from participants where true; end if;
  update state set phase = 'idle', opened_at = null, revealed_correct = null, podium_step = 0, present = null, updated_at = now() where id = 1;
end $$;

grant execute on function host_set_state(text, jsonb), hunt_submit(uuid, uuid, text, text, text), race_my_letters(uuid, uuid), race_place(uuid, uuid, text, int), race_clear(uuid, uuid, int), race_help_me(uuid, uuid, text), hunt_board(), sap_summary(int), host_sap_accuracy(text), submit_feedback(uuid, uuid, jsonb), host_feedback(text), host_reset(text, text) to anon, authenticated;
revoke execute on function _race_owned(participants, text) from anon, authenticated;

-- 7) Helper cards: scanning one just says what it is (open from the briefing on).
create or replace function spot_info(p_code text) returns json
language plpgsql stable security definer set search_path = public as $$
declare k hunt_spot_keys;
begin
  if not ('lake' = any(coalesce((select live from state where id = 1), '{}'))) then raise exception 'The helper cards open at the briefing.'; end if;
  select * into k from hunt_spot_keys where code = upper(btrim(coalesce(p_code, '')));
  if not found then raise exception 'Unknown helper card'; end if;
  return json_build_object('name', k.name, 'explain', k.explain);
end $$;
grant execute on function spot_info(text) to anon, authenticated;
