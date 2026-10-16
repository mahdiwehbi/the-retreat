-- WASH Retreat, part 2: all retreat exercises.
-- Adds team worksheets, sticky-note boards with dot voting, budget allocation,
-- a find-the-right-card treasure hunt, and the WASH SAP field test.
-- Run after schema.sql. Running it again is safe.

-- 1) New activity kinds -------------------------------------------------------------

alter table activities drop constraint if exists activities_kind_check;
alter table activities add constraint activities_kind_check
  check (kind in ('poll', 'words', 'rating', 'quiz', 'open', 'board', 'dots', 'team', 'allocate'));

-- Sticky notes on a board (many per person) and dot votes on them.
create table if not exists notes (
  id bigserial primary key,
  activity_id uuid not null references activities(id) on delete cascade,
  participant_id uuid not null references participants(id) on delete cascade,
  team_id int,
  col int not null default 0,
  tag int not null default 0,
  text text not null check (char_length(text) between 1 and 200),
  created_at timestamptz not null default now()
);

create table if not exists note_votes (
  note_id bigint not null references notes(id) on delete cascade,
  participant_id uuid not null references participants(id) on delete cascade,
  activity_id uuid not null references activities(id) on delete cascade,
  primary key (note_id, participant_id)
);

-- One shared worksheet per team per activity.
create table if not exists team_entries (
  activity_id uuid not null references activities(id) on delete cascade,
  team_id int not null references teams(id),
  data jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  primary key (activity_id, team_id)
);

alter table notes enable row level security;
alter table note_votes enable row level security;
alter table team_entries enable row level security;

do $$
declare t text;
begin
  foreach t in array array['notes', 'note_votes', 'team_entries'] loop
    execute format('drop policy if exists "public read" on %I', t);
    execute format('create policy "public read" on %I for select to anon, authenticated using (true)', t);
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end $$;
grant select on notes, note_votes, team_entries to anon, authenticated;

-- 2) Exercise functions --------------------------------------------------------------

-- Checks that the activity is the one on screen and open.
create or replace function _open_activity(p_activity uuid) returns activities
language plpgsql stable security definer set search_path = public as $$
declare st state; a activities;
begin
  select * into st from state where id = 1;
  if st.activity_id is distinct from p_activity or st.phase <> 'open' then
    raise exception 'This exercise is closed. Look at the screen.';
  end if;
  select * into a from activities where id = p_activity;
  return a;
end $$;
revoke execute on function _open_activity(uuid) from public, anon, authenticated;

create or replace function add_note(p_pid uuid, p_token uuid, p_activity uuid, p_col int, p_tag int, p_text text) returns bigint
language plpgsql security definer set search_path = public as $$
declare me participants; a activities; v_id bigint; v_text text := left(btrim(coalesce(p_text, '')), 200);
begin
  me := _player(p_pid, p_token);
  a := _open_activity(p_activity);
  if a.kind <> 'board' then raise exception 'Notes go on a board'; end if;
  if v_text = '' then raise exception 'Write something first'; end if;
  if (select count(*) from notes where activity_id = a.id and participant_id = me.id) >= 15 then
    raise exception 'You already added 15 notes';
  end if;
  insert into notes (activity_id, participant_id, team_id, col, tag, text)
    values (a.id, me.id, me.team_id,
            greatest(0, least(coalesce(p_col, 0), jsonb_array_length(coalesce(a.options->'columns', '[]'::jsonb)) - 1)),
            greatest(0, least(coalesce(p_tag, 0), jsonb_array_length(coalesce(a.options->'tags', '[]'::jsonb)) - 1)),
            v_text)
    returning id into v_id;
  return v_id;
end $$;

create or replace function delete_note(p_pid uuid, p_token uuid, p_note bigint) returns void
language plpgsql security definer set search_path = public as $$
declare me participants;
begin
  me := _player(p_pid, p_token);
  delete from notes where id = p_note and participant_id = me.id;
end $$;

create or replace function toggle_vote(p_pid uuid, p_token uuid, p_activity uuid, p_note bigint) returns text
language plpgsql security definer set search_path = public as $$
declare me participants; a activities; v_board uuid; v_max int;
begin
  me := _player(p_pid, p_token);
  a := _open_activity(p_activity);
  if a.kind <> 'dots' then raise exception 'Voting is not open'; end if;
  v_board := nullif(a.options->>'board', '')::uuid;
  v_max := coalesce((a.options->>'dots')::int, 3);
  if not exists (select 1 from notes where id = p_note and activity_id = v_board) then
    raise exception 'That note is not on this board';
  end if;
  if exists (select 1 from note_votes where note_id = p_note and participant_id = me.id) then
    delete from note_votes where note_id = p_note and participant_id = me.id;
    return 'removed';
  end if;
  if (select count(*) from note_votes where activity_id = a.id and participant_id = me.id) >= v_max then
    return 'full';
  end if;
  insert into note_votes (note_id, participant_id, activity_id) values (p_note, me.id, a.id);
  return 'added';
end $$;

-- Team worksheet edits. p_op: 'set' a text field, 'add' a list item, 'remove' a list item.
create or replace function team_edit(p_pid uuid, p_token uuid, p_activity uuid, p_field int, p_op text, p_text text, p_tag int default null, p_index int default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me participants; a activities; d jsonb; k text := 'f' || p_field; lst jsonb; v_text text := left(btrim(coalesce(p_text, '')), 400);
begin
  me := _player(p_pid, p_token);
  a := _open_activity(p_activity);
  if a.kind <> 'team' then raise exception 'This is not a team worksheet'; end if;
  if p_field < 0 or p_field >= jsonb_array_length(coalesce(a.options->'fields', '[]'::jsonb)) then raise exception 'Unknown field'; end if;
  insert into team_entries (activity_id, team_id) values (a.id, me.team_id) on conflict do nothing;
  select data into d from team_entries where activity_id = a.id and team_id = me.team_id for update;
  if p_op = 'set' then
    d := jsonb_set(d, array[k], to_jsonb(v_text));
  elsif p_op = 'add' then
    if v_text = '' then raise exception 'Write something first'; end if;
    lst := coalesce(d->k, '[]'::jsonb);
    if jsonb_typeof(lst) <> 'array' then lst := '[]'::jsonb; end if;
    if jsonb_array_length(lst) >= 40 then raise exception 'This list is full'; end if;
    lst := lst || jsonb_build_array(jsonb_build_object('t', v_text, 'g', p_tag, 'by', me.name));
    d := jsonb_set(d, array[k], lst);
  elsif p_op = 'remove' then
    lst := coalesce(d->k, '[]'::jsonb);
    if jsonb_typeof(lst) = 'array' and p_index is not null and p_index >= 0 and p_index < jsonb_array_length(lst) then
      d := jsonb_set(d, array[k], lst - p_index);
    end if;
  end if;
  if length(d::text) > 60000 then raise exception 'This worksheet is too long'; end if;
  update team_entries set data = d, updated_at = now() where activity_id = a.id and team_id = me.team_id;
  return d;
end $$;

-- Allocation answers ride on submit_response: allow the new kinds there.
create or replace function submit_response(p_pid uuid, p_token uuid, p_activity uuid, p_value jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare
  me participants; st state; a activities; v jsonb; n int; v_elapsed int; v_budget int; v_total int; v_len int;
begin
  me := _player(p_pid, p_token);
  select * into st from state where id = 1;
  if st.activity_id is distinct from p_activity or st.phase <> 'open' then
    return 'closed';
  end if;
  select * into a from activities where id = p_activity;
  v_elapsed := greatest(0, (extract(epoch from (clock_timestamp() - coalesce(st.opened_at, now()))) * 1000)::int);

  if a.kind in ('poll', 'quiz') then
    n := nullif(p_value->>'choice', '')::int;
    if n is null or n < 0 or n >= jsonb_array_length(a.options) then raise exception 'Pick one option'; end if;
    v := jsonb_build_object('choice', n);
  elsif a.kind = 'rating' then
    n := nullif(p_value->>'score', '')::int;
    if n is null or n < 1 or n > 5 then raise exception 'Pick a number from 1 to 5'; end if;
    v := jsonb_build_object('score', n);
  elsif a.kind = 'words' then
    select jsonb_agg(w) into v from (
      select left(btrim(x), 30) as w from jsonb_array_elements_text(coalesce(p_value->'words', '[]'::jsonb)) as x
      where btrim(x) <> '' limit greatest(1, a.max_words)) s;
    if v is null then raise exception 'Type at least one word'; end if;
    v := jsonb_build_object('words', v);
  elsif a.kind = 'allocate' then
    v_budget := coalesce((a.options->>'budget')::int, 100);
    v_len := greatest(1, coalesce(jsonb_array_length(a.options->'items'), 0));
    if coalesce(jsonb_array_length(a.options->'items'), 0) = 0 then v_len := (select count(*) from teams); end if;
    select coalesce(jsonb_agg(greatest(0, least(v_budget, coalesce((x)::text::int, 0))) order by i), '[]'::jsonb), coalesce(sum(greatest(0, coalesce((x)::text::int, 0))), 0)
      into v, v_total
      from jsonb_array_elements(coalesce(p_value->'alloc', '[]'::jsonb)) with ordinality as e(x, i) where i <= v_len;
    if v_total > v_budget then raise exception 'You can give at most % in total', v_budget; end if;
    if v_total = 0 then raise exception 'Give something to at least one'; end if;
    v := jsonb_build_object('alloc', v);
  elsif a.kind = 'open' then
    v := jsonb_build_object('text', left(btrim(coalesce(p_value->>'text', '')), 280));
    if v->>'text' = '' then raise exception 'Type an answer first'; end if;
  else
    raise exception 'This exercise takes answers in its own way';
  end if;

  if a.kind = 'quiz' then
    if v_elapsed > a.time_limit * 1000 + 2000 then return 'late'; end if;
    insert into responses (activity_id, participant_id, team_id, value, elapsed_ms)
      values (p_activity, me.id, me.team_id, v, v_elapsed)
      on conflict (activity_id, participant_id) do nothing;
    if not found then return 'already'; end if;
  else
    insert into responses (activity_id, participant_id, team_id, value, elapsed_ms)
      values (p_activity, me.id, me.team_id, v, v_elapsed)
      on conflict (activity_id, participant_id) do update set value = excluded.value, created_at = now();
  end if;
  return 'ok';
end $$;

create or replace function host_clear_responses(p_pin text, p_activity uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  delete from responses where activity_id = p_activity;
  delete from notes where activity_id = p_activity;
  delete from note_votes where activity_id = p_activity;
  delete from team_entries where activity_id = p_activity;
end $$;

-- 3) Treasure hunt: clues and the cards hidden around the lake ---------------------------
-- A "find" clue is solved by scanning the right spot card. Spot cards describe something
-- (a latrine, a water source...); teams must apply the WAP definitions to pick the right one.

alter table hunt_cards drop constraint if exists hunt_cards_kind_check;
alter table hunt_cards add constraint hunt_cards_kind_check check (kind in ('quiz', 'text', 'photo', 'find'));

create table if not exists hunt_spots (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  grp text not null default '',
  title text not null default '',
  description text not null default '',
  position int not null default 0
);
alter table hunt_spots enable row level security;
drop policy if exists "public read" on hunt_spots;
create policy "public read" on hunt_spots for select to anon, authenticated using (true);
grant select on hunt_spots to anon, authenticated;

create or replace function host_save_spot(p_pin text, p_id uuid, p_data jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid := p_id;
begin
  perform _need_host(p_pin);
  if v_id is null then
    insert into hunt_spots (code, grp, title, description, position) values (
      upper(coalesce(nullif(btrim(p_data->>'code'), ''), 'S' || substr(md5(random()::text), 1, 4))),
      coalesce(p_data->>'grp', ''), coalesce(p_data->>'title', ''), coalesce(p_data->>'description', ''),
      coalesce((p_data->>'position')::int, (select coalesce(max(position), 0) + 1 from hunt_spots)))
    returning id into v_id;
  else
    update hunt_spots set
      code = upper(coalesce(nullif(btrim(p_data->>'code'), ''), code)),
      grp = coalesce(p_data->>'grp', grp), title = coalesce(p_data->>'title', title),
      description = coalesce(p_data->>'description', description),
      position = coalesce((p_data->>'position')::int, position)
    where id = v_id;
  end if;
  return v_id;
end $$;

create or replace function host_delete_spot(p_pin text, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  delete from hunt_spots where id = p_id;
end $$;

-- Which clues has my team solved, and how many tries are left on each (no answers revealed).
create or replace function hunt_my_team(p_pid uuid, p_token uuid) returns json
language plpgsql stable security definer set search_path = public as $$
declare me participants; v_secret text;
begin
  me := _player(p_pid, p_token);
  select value into v_secret from secrets where key = 'hunt_secret';
  return (select coalesce(json_agg(json_build_object(
      'id', c.id, 'code', c.code,
      'solved', exists (select 1 from hunt_finds f where f.card_id = c.id and f.team_id = me.team_id and f.correct),
      'wrong', (select count(*) from hunt_finds f where f.card_id = c.id and f.team_id = me.team_id and not f.correct),
      'letter', case when exists (select 1 from hunt_finds f where f.card_id = c.id and f.team_id = me.team_id and f.correct)
                      and c.letter_index is not null and c.letter_index < char_length(coalesce(v_secret, ''))
                     then substr(v_secret, c.letter_index + 1, 1) end
    ) order by c.position, c.code), '[]'::json) from hunt_cards c);
end $$;

-- 4) WASH SAP field test: one site form + many household forms per team ------------------

create table if not exists sap_tents (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  team_id int not null references teams(id),
  number int not null,
  card text not null default ''
);
create table if not exists sap_truth (
  tent_id uuid primary key references sap_tents(id) on delete cascade,
  data jsonb not null
);
create table if not exists sap_sites (
  team_id int primary key references teams(id),
  data jsonb not null default '{}',
  participant_id uuid references participants(id) on delete set null,
  started_at timestamptz,
  updated_at timestamptz not null default now()
);
create table if not exists sap_households (
  id bigserial primary key,
  team_id int not null references teams(id),
  tent_id uuid not null references sap_tents(id) on delete cascade,
  participant_id uuid references participants(id) on delete set null,
  data jsonb not null,
  kap jsonb,
  started_at timestamptz,
  created_at timestamptz not null default now(),
  unique (team_id, tent_id)
);
alter table sap_tents enable row level security;
alter table sap_truth enable row level security;
alter table sap_sites enable row level security;
alter table sap_households enable row level security;
drop policy if exists "public read" on sap_tents;
create policy "public read" on sap_tents for select to anon, authenticated using (true);
grant select on sap_tents to anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['sap_sites', 'sap_households'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end $$;

create or replace function sap_save_site(p_pid uuid, p_token uuid, p_data jsonb, p_started timestamptz) returns void
language plpgsql security definer set search_path = public as $$
declare me participants;
begin
  me := _player(p_pid, p_token);
  if length(coalesce(p_data, '{}'::jsonb)::text) > 20000 then raise exception 'Too long'; end if;
  insert into sap_sites (team_id, data, participant_id, started_at, updated_at)
    values (me.team_id, coalesce(p_data, '{}'::jsonb), me.id, p_started, now())
    on conflict (team_id) do update set data = excluded.data, participant_id = excluded.participant_id,
      started_at = coalesce(sap_sites.started_at, excluded.started_at), updated_at = now();
end $$;

create or replace function sap_save_household(p_pid uuid, p_token uuid, p_tent text, p_data jsonb, p_kap jsonb, p_started timestamptz) returns text
language plpgsql security definer set search_path = public as $$
declare me participants; t sap_tents;
begin
  me := _player(p_pid, p_token);
  select * into t from sap_tents where upper(code) = upper(btrim(coalesce(p_tent, '')));
  if not found then raise exception 'This tent card is not part of the test'; end if;
  if t.team_id <> me.team_id then raise exception 'This tent belongs to another team''s site'; end if;
  if length(coalesce(p_data, '{}'::jsonb)::text) > 10000 then raise exception 'Too long'; end if;
  insert into sap_households (team_id, tent_id, participant_id, data, kap, started_at)
    values (me.team_id, t.id, me.id, coalesce(p_data, '{}'::jsonb), p_kap, p_started)
    on conflict (team_id, tent_id) do update set data = excluded.data, kap = excluded.kap,
      participant_id = excluded.participant_id, created_at = now();
  return 'ok';
end $$;

-- The live site summary: household answers added up, plus the site form.
create or replace function sap_summary(p_team int) returns json
language plpgsql stable security definer set search_path = public as $$
declare n_tents int; n_done int; site jsonb; hh jsonb;
begin
  select count(*) into n_tents from sap_tents where team_id = p_team;
  select count(*) into n_done from sap_households where team_id = p_team;
  select data into site from sap_sites where team_id = p_team;
  select coalesce(jsonb_agg(h.data || jsonb_build_object('tent', t.number, 'kap', h.kap is not null, 'by', p.name, 'at', h.created_at, 'started', h.started_at) order by t.number), '[]'::jsonb)
    into hh from sap_households h join sap_tents t on t.id = h.tent_id left join participants p on p.id = h.participant_id
    where h.team_id = p_team;
  return json_build_object('tents', n_tents, 'done', n_done, 'site', coalesce(site, '{}'::jsonb), 'households', hh,
    'site_by', (select p.name from sap_sites s left join participants p on p.id = s.participant_id where s.team_id = p_team),
    'site_at', (select updated_at from sap_sites where team_id = p_team),
    'first_start', (select min(x) from (select started_at x from sap_households where team_id = p_team union all select started_at from sap_sites where team_id = p_team) z));
end $$;

-- Accuracy against the truth printed on the tent cards (host only).
create or replace function host_sap_accuracy(p_pin text) returns json
language plpgsql stable security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  return (select coalesce(json_agg(json_build_object('team_id', tm.id, 'checked', x.checked, 'right', x.right_n) order by tm.id), '[]'::json)
    from teams tm left join lateral (
      select count(*) as checked, count(*) filter (where (h.data->>k.key) = (tr.data->>k.key)) as right_n
      from sap_households h join sap_truth tr on tr.tent_id = h.tent_id, jsonb_object_keys(tr.data) as k(key)
      where h.team_id = tm.id
    ) x on true);
end $$;

create or replace function host_reset(p_pin text, p_what text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  if p_what in ('answers', 'all') then
    delete from responses where true; delete from notes where true; delete from note_votes where true; delete from team_entries where true;
  end if;
  if p_what in ('points', 'all') then delete from team_points where true; end if;
  if p_what in ('hunt', 'all') then delete from hunt_finds where true; end if;
  if p_what in ('checks', 'all') then
    delete from assessments where true; delete from sap_households where true; delete from sap_sites where true;
  end if;
  if p_what in ('players', 'all') then delete from participants where true; end if;
  update state set phase = 'idle', opened_at = null, revealed_correct = null, podium_step = 0, updated_at = now() where id = 1;
end $$;

-- Hunt finds made by scanning a spot card count toward the team score like any other card.
-- (scoreboard() already sums hunt_cards.points for correct finds.)

grant execute on function add_note(uuid, uuid, uuid, int, int, text), delete_note(uuid, uuid, bigint),
  toggle_vote(uuid, uuid, uuid, bigint), team_edit(uuid, uuid, uuid, int, text, text, int, int),
  hunt_my_team(uuid, uuid), sap_save_site(uuid, uuid, jsonb, timestamptz),
  sap_save_household(uuid, uuid, text, jsonb, jsonb, timestamptz), sap_summary(int),
  host_save_spot(text, uuid, jsonb), host_delete_spot(text, uuid), host_sap_accuracy(text)
  to anon, authenticated;
