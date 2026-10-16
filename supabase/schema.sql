-- WASH Retreat: database setup for Supabase.
-- Paste the whole file into Supabase > SQL Editor > New query, change the passphrase
-- at the bottom (section 9), and press Run. Running it again is safe: it keeps your data.

create extension if not exists pgcrypto with schema extensions;

-- 1) Tables -------------------------------------------------------------------

create table if not exists teams (
  id int primary key,
  name text not null,
  color text not null
);
insert into teams (id, name, color) values
  (1, 'Team 1', '#2F5DA8'), (2, 'Team 2', '#B8561A'), (3, 'Team 3', '#7442AD')
on conflict (id) do nothing;

create table if not exists participants (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  team_id int references teams(id),
  created_at timestamptz not null default now()
);

create table if not exists participant_tokens (
  participant_id uuid primary key references participants(id) on delete cascade,
  token uuid not null default gen_random_uuid()
);

create table if not exists activities (
  id uuid primary key default gen_random_uuid(),
  position int not null default 0,
  kind text not null check (kind in ('poll', 'words', 'rating', 'quiz', 'open')),
  title text not null default '',
  options jsonb not null default '[]',
  time_limit int not null default 20,
  max_words int not null default 3,
  created_at timestamptz not null default now()
);

create table if not exists activity_keys (
  activity_id uuid primary key references activities(id) on delete cascade,
  correct int
);

create table if not exists state (
  id int primary key default 1 check (id = 1),
  activity_id uuid references activities(id) on delete set null,
  phase text not null default 'idle' check (phase in ('idle', 'open', 'closed', 'reveal')),
  screen text not null default 'lobby' check (screen in ('lobby', 'activity', 'leaderboard', 'teams', 'podium', 'hunt')),
  opened_at timestamptz,
  revealed_correct int,
  podium_step int not null default 0,
  updated_at timestamptz not null default now()
);
insert into state (id) values (1) on conflict (id) do nothing;

create table if not exists responses (
  id bigserial primary key,
  activity_id uuid not null references activities(id) on delete cascade,
  participant_id uuid not null references participants(id) on delete cascade,
  team_id int,
  value jsonb not null,
  elapsed_ms int not null default 0,
  correct boolean,
  points int not null default 0,
  created_at timestamptz not null default now(),
  unique (activity_id, participant_id)
);

create table if not exists team_points (
  id bigserial primary key,
  team_id int not null references teams(id),
  points int not null,
  reason text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists hunt_cards (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  position int not null default 0,
  kind text not null default 'text' check (kind in ('quiz', 'text', 'photo')),
  prompt text not null default '',
  options jsonb not null default '[]',
  letter_index int,
  points int not null default 1,
  golden boolean not null default false
);

create table if not exists hunt_keys (
  card_id uuid primary key references hunt_cards(id) on delete cascade,
  answer text not null default ''
);

create table if not exists hunt_finds (
  id bigserial primary key,
  card_id uuid not null references hunt_cards(id) on delete cascade,
  team_id int not null references teams(id),
  participant_id uuid references participants(id) on delete set null,
  answer text,
  photo text,
  correct boolean not null,
  created_at timestamptz not null default now()
);
create unique index if not exists hunt_finds_one_per_team on hunt_finds (card_id, team_id) where correct;

create table if not exists assessments (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid references participants(id) on delete set null,
  team_id int,
  site text not null default '',
  answers jsonb not null default '{}',
  photos jsonb not null default '[]',
  lat double precision,
  lng double precision,
  score int,
  created_at timestamptz not null default now()
);

create table if not exists secrets (
  key text primary key,
  value text not null
);

-- 2) Who can read what --------------------------------------------------------
-- Everyone with the link can read the public game tables. Nobody can write to any
-- table directly: every write goes through the functions below, which check the
-- player's token or the host passphrase. Answers, the secret word, hunt finds and
-- site checks are never readable directly.

alter table teams enable row level security;
alter table participants enable row level security;
alter table participant_tokens enable row level security;
alter table activities enable row level security;
alter table activity_keys enable row level security;
alter table state enable row level security;
alter table responses enable row level security;
alter table team_points enable row level security;
alter table hunt_cards enable row level security;
alter table hunt_keys enable row level security;
alter table hunt_finds enable row level security;
alter table assessments enable row level security;
alter table secrets enable row level security;

do $$
declare t text;
begin
  foreach t in array array['teams', 'participants', 'activities', 'state', 'responses', 'team_points', 'hunt_cards'] loop
    execute format('drop policy if exists "public read" on %I', t);
    execute format('create policy "public read" on %I for select to anon, authenticated using (true)', t);
  end loop;
end $$;

-- 3) Live updates -------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array['teams', 'participants', 'activities', 'state', 'responses', 'team_points', 'hunt_cards'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end $$;

-- 4) Photo storage --------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists "retreat photo upload" on storage.objects;
create policy "retreat photo upload" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'photos');

-- 5) Helpers (not callable from the app) -----------------------------------------

create or replace function _host_ok(p_pin text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (select 1 from secrets where key = 'host_pin' and value = extensions.crypt(coalesce(p_pin, ''), value));
$$;

create or replace function _need_host(p_pin text) returns void
language plpgsql stable security definer set search_path = public, extensions as $$
begin
  if not _host_ok(p_pin) then
    raise exception 'Wrong host passphrase' using errcode = '42501';
  end if;
end $$;

create or replace function _player(p_pid uuid, p_token uuid) returns participants
language plpgsql stable security definer set search_path = public as $$
declare r participants;
begin
  select p.* into r from participants p
    join participant_tokens t on t.participant_id = p.id
    where p.id = p_pid and t.token = p_token;
  if not found then
    raise exception 'Please join again' using errcode = '28000';
  end if;
  return r;
end $$;

revoke execute on function _host_ok(text) from public, anon, authenticated;
revoke execute on function _need_host(text) from public, anon, authenticated;
revoke execute on function _player(uuid, uuid) from public, anon, authenticated;

-- 6) Player functions ---------------------------------------------------------------

create or replace function server_time() returns double precision
language sql stable as $$ select extract(epoch from clock_timestamp()) * 1000 $$;

create or replace function join_retreat(p_name text, p_team int default null) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid; v_tok uuid; v_team int;
  v_name text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
begin
  if char_length(v_name) < 1 or char_length(v_name) > 40 then
    raise exception 'Please enter your name (up to 40 letters)';
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

create or replace function submit_response(p_pid uuid, p_token uuid, p_activity uuid, p_value jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare
  me participants; st state; a activities; v jsonb; n int; v_elapsed int;
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
    if n is null or n < 0 or n >= jsonb_array_length(a.options) then
      raise exception 'Pick one option';
    end if;
    v := jsonb_build_object('choice', n);
  elsif a.kind = 'rating' then
    n := nullif(p_value->>'score', '')::int;
    if n is null or n < 1 or n > 5 then
      raise exception 'Pick a number from 1 to 5';
    end if;
    v := jsonb_build_object('score', n);
  elsif a.kind = 'words' then
    select jsonb_agg(w) into v from (
      select left(btrim(x), 30) as w
      from jsonb_array_elements_text(coalesce(p_value->'words', '[]'::jsonb)) as x
      where btrim(x) <> '' limit greatest(1, a.max_words)
    ) s;
    if v is null then
      raise exception 'Type at least one word';
    end if;
    v := jsonb_build_object('words', v);
  else
    v := jsonb_build_object('text', left(btrim(coalesce(p_value->>'text', '')), 280));
    if v->>'text' = '' then
      raise exception 'Type an answer first';
    end if;
  end if;

  if a.kind = 'quiz' then
    if v_elapsed > a.time_limit * 1000 + 2000 then
      return 'late';
    end if;
    insert into responses (activity_id, participant_id, team_id, value, elapsed_ms)
      values (p_activity, me.id, me.team_id, v, v_elapsed)
      on conflict (activity_id, participant_id) do nothing;
    if not found then
      return 'already';
    end if;
  else
    insert into responses (activity_id, participant_id, team_id, value, elapsed_ms)
      values (p_activity, me.id, me.team_id, v, v_elapsed)
      on conflict (activity_id, participant_id)
      do update set value = excluded.value, created_at = now();
  end if;
  return 'ok';
end $$;

create or replace function scoreboard() returns json
language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
    'team_id', t.id, 'name', t.name, 'color', t.color,
    'manual', coalesce((select sum(points) from team_points where team_id = t.id), 0),
    'hunt', coalesce((select sum(c.points) from hunt_finds f join hunt_cards c on c.id = f.card_id where f.team_id = t.id and f.correct), 0),
    'quiz', (select count(*) from responses r where r.team_id = t.id and r.correct),
    'members', (select count(*) from participants p where p.team_id = t.id)
  ) order by t.id), '[]'::json) from teams t;
$$;

create or replace function hunt_board() returns json
language plpgsql stable security definer set search_path = public as $$
declare v_secret text;
begin
  select value into v_secret from secrets where key = 'hunt_secret';
  v_secret := coalesce(v_secret, '');
  return json_build_object(
    'length', char_length(v_secret),
    'cards', (select count(*) from hunt_cards),
    'teams', (select coalesce(json_agg(json_build_object(
      'team_id', t.id,
      'found', (select count(*) from hunt_finds f where f.team_id = t.id and f.correct),
      'letters', (select coalesce(json_agg(json_build_object('i', c.letter_index, 'l', substr(v_secret, c.letter_index + 1, 1))), '[]'::json)
                  from hunt_finds f join hunt_cards c on c.id = f.card_id
                  where f.team_id = t.id and f.correct and c.letter_index is not null
                    and c.letter_index >= 0 and c.letter_index < char_length(v_secret))
    ) order by t.id), '[]'::json) from teams t)
  );
end $$;

create or replace function hunt_submit(p_pid uuid, p_token uuid, p_code text, p_answer text, p_photo text default null) returns json
language plpgsql security definer set search_path = public as $$
declare
  me participants; c hunt_cards; k text; ok boolean; v_wrong int; v_secret text; v_letter text;
begin
  me := _player(p_pid, p_token);
  select * into c from hunt_cards where upper(code) = upper(btrim(coalesce(p_code, '')));
  if not found then
    raise exception 'This card is not part of the game';
  end if;
  select value into v_secret from secrets where key = 'hunt_secret';
  if c.letter_index is not null and c.letter_index >= 0 and c.letter_index < char_length(coalesce(v_secret, '')) then
    v_letter := substr(v_secret, c.letter_index + 1, 1);
  end if;
  if exists (select 1 from hunt_finds where card_id = c.id and team_id = me.team_id and correct) then
    return json_build_object('status', 'already', 'letter', v_letter, 'position', c.letter_index);
  end if;
  select count(*) into v_wrong from hunt_finds where card_id = c.id and team_id = me.team_id and not correct;
  if v_wrong >= 3 then
    return json_build_object('status', 'locked');
  end if;
  select answer into k from hunt_keys where card_id = c.id;
  k := coalesce(k, '');
  if c.kind = 'photo' then
    ok := coalesce(p_photo, '') <> '';
  elsif btrim(k) = '' then
    ok := btrim(coalesce(p_answer, '')) <> '';
  elsif c.kind = 'quiz' then
    ok := btrim(coalesce(p_answer, '')) = btrim(k);
  else
    ok := exists (select 1 from unnest(string_to_array(k, '|')) as a(x)
                  where lower(btrim(x)) = lower(btrim(coalesce(p_answer, ''))));
  end if;
  begin
    insert into hunt_finds (card_id, team_id, participant_id, answer, photo, correct)
      values (c.id, me.team_id, me.id, left(p_answer, 300), left(p_photo, 500), ok);
  exception when unique_violation then
    return json_build_object('status', 'already', 'letter', v_letter, 'position', c.letter_index);
  end;
  if ok then
    return json_build_object('status', 'correct', 'letter', v_letter, 'position', c.letter_index, 'points', c.points);
  end if;
  return json_build_object('status', 'wrong', 'left', 2 - v_wrong);
end $$;

create or replace function submit_assessment(p_pid uuid, p_token uuid, p_site text, p_answers jsonb,
  p_photos jsonb, p_lat double precision, p_lng double precision, p_score int) returns uuid
language plpgsql security definer set search_path = public as $$
declare me participants; v_id uuid;
begin
  me := _player(p_pid, p_token);
  if length(coalesce(p_answers, '{}'::jsonb)::text) > 20000 or length(coalesce(p_photos, '[]'::jsonb)::text) > 10000 then
    raise exception 'This site check is too long';
  end if;
  insert into assessments (participant_id, team_id, site, answers, photos, lat, lng, score)
    values (me.id, me.team_id, left(coalesce(p_site, ''), 120), coalesce(p_answers, '{}'::jsonb),
            coalesce(p_photos, '[]'::jsonb), p_lat, p_lng, p_score)
    returning id into v_id;
  return v_id;
end $$;

-- 7) Host functions (all need the host passphrase) -----------------------------------------

create or replace function host_check(p_pin text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select _host_ok(p_pin);
$$;

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
  if p_patch ? 'podium_step' then st.podium_step := greatest(0, least(3, (p_patch->>'podium_step')::int)); end if;
  update state set activity_id = st.activity_id, phase = st.phase, screen = st.screen,
    opened_at = st.opened_at, revealed_correct = st.revealed_correct,
    podium_step = st.podium_step, updated_at = now()
    where id = 1;
end $$;

create or replace function host_save_activity(p_pin text, p_id uuid, p_data jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid := p_id;
begin
  perform _need_host(p_pin);
  if v_id is null then
    insert into activities (position, kind, title, options, time_limit, max_words) values (
      coalesce((p_data->>'position')::int, (select coalesce(max(position), 0) + 1 from activities)),
      coalesce(p_data->>'kind', 'poll'), coalesce(p_data->>'title', ''),
      coalesce(p_data->'options', '[]'::jsonb), coalesce((p_data->>'time_limit')::int, 20),
      coalesce((p_data->>'max_words')::int, 3))
    returning id into v_id;
  else
    update activities set
      position = coalesce((p_data->>'position')::int, position),
      kind = coalesce(p_data->>'kind', kind),
      title = coalesce(p_data->>'title', title),
      options = coalesce(p_data->'options', options),
      time_limit = coalesce((p_data->>'time_limit')::int, time_limit),
      max_words = coalesce((p_data->>'max_words')::int, max_words)
    where id = v_id;
  end if;
  if p_data ? 'correct' then
    insert into activity_keys (activity_id, correct) values (v_id, nullif(p_data->>'correct', '')::int)
      on conflict (activity_id) do update set correct = excluded.correct;
  end if;
  return v_id;
end $$;

create or replace function host_delete_activity(p_pin text, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  delete from activities where id = p_id;
end $$;

create or replace function host_keys(p_pin text) returns json
language plpgsql stable security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  return (select coalesce(json_object_agg(activity_id, correct), '{}'::json) from activity_keys);
end $$;

create or replace function host_clear_responses(p_pin text, p_activity uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  delete from responses where activity_id = p_activity;
end $$;

create or replace function host_add_points(p_pin text, p_team int, p_points int, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  insert into team_points (team_id, points, reason) values (p_team, p_points, left(coalesce(p_reason, ''), 120));
end $$;

create or replace function host_delete_points(p_pin text, p_id bigint) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  delete from team_points where id = p_id;
end $$;

create or replace function host_rename_team(p_pin text, p_team int, p_name text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  update teams set name = left(btrim(p_name), 40) where id = p_team and btrim(p_name) <> '';
end $$;

create or replace function host_move_player(p_pin text, p_pid uuid, p_team int) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  update participants set team_id = p_team where id = p_pid;
end $$;

create or replace function host_delete_player(p_pin text, p_pid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  delete from participants where id = p_pid;
end $$;

create or replace function host_cards(p_pin text) returns json
language plpgsql stable security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  return json_build_object(
    'secret', coalesce((select value from secrets where key = 'hunt_secret'), ''),
    'cards', (select coalesce(json_agg(x order by x.position, x.code), '[]'::json) from (
      select c.*, coalesce(k.answer, '') as answer from hunt_cards c left join hunt_keys k on k.card_id = c.id) x));
end $$;

create or replace function host_save_card(p_pin text, p_id uuid, p_data jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid := p_id;
begin
  perform _need_host(p_pin);
  if v_id is null then
    insert into hunt_cards (code, position, kind, prompt, options, letter_index, points, golden) values (
      upper(coalesce(nullif(btrim(p_data->>'code'), ''), substr(md5(random()::text), 1, 5))),
      coalesce((p_data->>'position')::int, (select coalesce(max(position), 0) + 1 from hunt_cards)),
      coalesce(p_data->>'kind', 'text'), coalesce(p_data->>'prompt', ''),
      coalesce(p_data->'options', '[]'::jsonb), nullif(p_data->>'letter_index', '')::int,
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

create or replace function host_delete_card(p_pin text, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  delete from hunt_cards where id = p_id;
end $$;

create or replace function host_set_secret(p_pin text, p_word text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  insert into secrets (key, value) values ('hunt_secret', upper(regexp_replace(coalesce(p_word, ''), '[^A-Za-z]', '', 'g')))
    on conflict (key) do update set value = excluded.value;
end $$;

create or replace function host_finds(p_pin text) returns json
language plpgsql stable security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  return (select coalesce(json_agg(json_build_object(
      'id', f.id, 'code', c.code, 'prompt', c.prompt, 'team_id', f.team_id, 'player', p.name,
      'answer', f.answer, 'photo', f.photo, 'correct', f.correct, 'at', f.created_at
    ) order by f.created_at desc), '[]'::json)
    from hunt_finds f join hunt_cards c on c.id = f.card_id left join participants p on p.id = f.participant_id);
end $$;

create or replace function host_assessments(p_pin text) returns json
language plpgsql stable security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  return (select coalesce(json_agg(json_build_object(
      'id', a.id, 'site', a.site, 'team_id', a.team_id, 'player', p.name, 'answers', a.answers,
      'photos', a.photos, 'lat', a.lat, 'lng', a.lng, 'score', a.score, 'at', a.created_at
    ) order by a.created_at desc), '[]'::json)
    from assessments a left join participants p on p.id = a.participant_id);
end $$;

create or replace function host_reset(p_pin text, p_what text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  if p_what in ('answers', 'all') then delete from responses where true; end if;
  if p_what in ('points', 'all') then delete from team_points where true; end if;
  if p_what in ('hunt', 'all') then delete from hunt_finds where true; end if;
  if p_what in ('checks', 'all') then delete from assessments where true; end if;
  if p_what in ('players', 'all') then delete from participants where true; end if;
  update state set phase = 'idle', opened_at = null, revealed_correct = null, podium_step = 0, updated_at = now() where id = 1;
end $$;

-- 8) Starter content (added only when the tables are empty) ---------------------------------

do $$
declare v uuid;
begin
  if not exists (select 1 from activities) then
    insert into activities (position, kind, title, options, max_words) values
      (1, 'words', 'The war response in one word', '[]', 1);
    insert into activities (position, kind, title, options) values
      (2, 'poll', '3W and ActivityInfo reporting: keep, fix or kill?', '["Keep","Fix","Kill"]'),
      (3, 'poll', 'Referrals tab: keep, fix or kill?', '["Keep","Fix","Kill"]'),
      (4, 'poll', 'Gap and PIN analysis: keep, fix or kill?', '["Keep","Fix","Kill"]'),
      (5, 'poll', 'Collective shelter tabs: keep, fix or kill?', '["Keep","Fix","Kill"]'),
      (6, 'poll', 'Focal points and WhatsApp flow: keep, fix or kill?', '["Keep","Fix","Kill"]');
    insert into activities (position, kind, title, options, time_limit) values
      (7, 'quiz', '[Draft] Peak number of collective shelters receiving WASH support during the war?', '["[fill]","[fill]","[fill]","[fill]"]', 20)
      returning id into v;
    insert into activity_keys values (v, 0);
    insert into activities (position, kind, title, options, time_limit) values
      (8, 'quiz', '[Draft] How many partners reported WASH activities during the war?', '["[fill]","[fill]","[fill]","[fill]"]', 20)
      returning id into v;
    insert into activity_keys values (v, 0);
    insert into activities (position, kind, title, options, time_limit) values
      (9, 'quiz', 'Which referral type has the most rows in the war sheet''s Referrals tab?', '["Public Drinking Point","Reservoir damage","Provision of spare parts","Miscellaneous"]', 20)
      returning id into v;
    insert into activity_keys values (v, 0);
    insert into activities (position, kind, title, options) values
      (10, 'rating', 'How ready is the sector for a new escalation tomorrow?', '["Not ready","Fully ready"]'),
      (11, 'open', 'One thing coordination must start doing', '[]'),
      (12, 'poll', 'Best Excel Survivor', '["Nominee 1","Nominee 2","Nominee 3"]'),
      (13, 'poll', 'Fastest WhatsApp Reply', '["Nominee 1","Nominee 2","Nominee 3"]'),
      (14, 'poll', 'Calmest Under Pressure', '["Nominee 1","Nominee 2","Nominee 3"]'),
      (15, 'poll', 'Best Map Never Printed', '["Nominee 1","Nominee 2","Nominee 3"]');
    insert into activities (position, kind, title, options, max_words) values
      (16, 'words', 'One word for how you leave the retreat', '[]', 1);
  end if;

  if not exists (select 1 from hunt_cards) then
    for i in 0..9 loop
      insert into hunt_cards (code, position, kind, prompt, letter_index, points)
        values (upper(substr(md5(random()::text), 1, 5)), i + 1, 'text', '[Write the question for this card]', i, 1);
    end loop;
    insert into hunt_cards (code, position, kind, prompt, points, golden) values
      (upper(substr(md5(random()::text), 1, 5)), 11, 'photo', 'Golden card: take a team photo that shows a WASH risk around the lake', 2, true),
      (upper(substr(md5(random()::text), 1, 5)), 12, 'photo', 'Golden card: photograph the best example of safe water storage you can find', 2, true);
  end if;
end $$;

-- 9) Access for the app's public role ----------------------------------------------------

grant usage on schema public to anon, authenticated;
grant select on teams, participants, activities, state, responses, team_points, hunt_cards to anon, authenticated;
grant execute on all functions in schema public to anon, authenticated;
revoke execute on function _host_ok(text) from public, anon, authenticated;
revoke execute on function _need_host(text) from public, anon, authenticated;
revoke execute on function _player(uuid, uuid) from public, anon, authenticated;

-- 10) Secret word and a locked host passphrase ---------------------------------------------
-- The host passphrase starts as a random value nobody knows. Set your own with
-- supabase/set-passphrase.sql.

insert into secrets (key, value) values ('hunt_secret', 'RESILIENCE') on conflict (key) do nothing;

insert into secrets (key, value)
values ('host_pin', extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf')))
on conflict (key) do nothing;
