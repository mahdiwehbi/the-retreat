-- WASH Retreat, part 4: the Day 1 word race.
-- Everyone finds the card in their own room and scans it; the letter goes to their team.
-- Back from lunch, teams race to guess the whole phrase. The first right guess wins.

create table if not exists hunt_guesses (
  id bigserial primary key,
  team_id int not null references teams(id),
  participant_id uuid references participants(id) on delete set null,
  guess text not null,
  correct boolean not null,
  created_at timestamptz not null default now()
);
alter table hunt_guesses enable row level security;

-- Word breaks of the phrase, e.g. '5,2,4,3,3' for WATER IS LIFE FOR ALL. Public: it is the
-- blank pattern teams see, not the answer.
insert into secrets (key, value) values ('hunt_pattern', '5,2,4,3,3') on conflict (key) do update set value = excluded.value;

-- Room cards (cards that carry a letter) never lock: people can retry until they get it.
create or replace function hunt_submit(p_pid uuid, p_token uuid, p_code text, p_answer text, p_photo text default null) returns json
language plpgsql security definer set search_path = public as $$
declare
  me participants; c hunt_cards; k text; ok boolean; v_wrong int; v_secret text; v_letter text;
begin
  me := _player(p_pid, p_token);
  select * into c from hunt_cards where upper(code) = upper(btrim(coalesce(p_code, '')));
  if not found then raise exception 'This card is not part of the game'; end if;
  select value into v_secret from secrets where key = 'hunt_secret';
  if c.letter_index is not null and c.letter_index >= 0 and c.letter_index < char_length(coalesce(v_secret, '')) then
    v_letter := substr(v_secret, c.letter_index + 1, 1);
  end if;
  if exists (select 1 from hunt_finds where card_id = c.id and team_id = me.team_id and correct) then
    return json_build_object('status', 'already', 'letter', v_letter, 'position', c.letter_index);
  end if;
  select count(*) into v_wrong from hunt_finds where card_id = c.id and team_id = me.team_id and not correct;
  if v_wrong >= 3 and c.letter_index is null then return json_build_object('status', 'locked'); end if;
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
    return json_build_object('status', 'already', 'letter', v_letter, 'position', c.letter_index);
  end;
  if ok then return json_build_object('status', 'correct', 'letter', v_letter, 'position', c.letter_index, 'points', c.points); end if;
  return json_build_object('status', 'wrong', 'left', case when c.letter_index is null then 2 - v_wrong else 99 end);
end $$;

-- A team guesses the phrase. Spaces and case do not matter. 5 guesses per team.
create or replace function hunt_guess(p_pid uuid, p_token uuid, p_guess text) returns json
language plpgsql security definer set search_path = public as $$
declare me participants; v_secret text; v_g text; ok boolean; v_used int; v_first boolean;
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
  if v_first then
    insert into team_points (team_id, points, reason) values (me.team_id, 10, 'First to crack the secret word');
  elsif ok then
    insert into team_points (team_id, points, reason) values (me.team_id, 5, 'Cracked the secret word');
  end if;
  return json_build_object('status', case when ok then 'correct' else 'wrong' end, 'first', v_first, 'left', 4 - v_used);
end $$;

-- The board now carries the blank pattern, each team's guesses used and the winner.
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
      'found', (select count(*) from hunt_finds f join hunt_cards c on c.id = f.card_id where f.team_id = t.id and f.correct and c.letter_index is not null),
      'guesses', (select count(*) from hunt_guesses g where g.team_id = t.id)
    ) order by t.id), '[]'::json) from teams t)
  );
end $$;

-- The phrase once a team has solved it (or always for the host).
create or replace function hunt_reveal(p_pid uuid, p_token uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare me participants;
begin
  me := _player(p_pid, p_token);
  if exists (select 1 from hunt_guesses where team_id = me.team_id and correct) then
    return (select value from secrets where key = 'hunt_secret');
  end if;
  return null;
end $$;

create or replace function host_reset(p_pin text, p_what text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  if p_what in ('answers', 'all') then
    delete from responses where true; delete from notes where true; delete from note_votes where true; delete from team_entries where true;
  end if;
  if p_what in ('points', 'all') then delete from team_points where true; end if;
  if p_what in ('hunt', 'all') then delete from hunt_finds where true; delete from hunt_guesses where true; end if;
  if p_what in ('checks', 'all') then
    delete from assessments where true; delete from sap_households where true; delete from sap_sites where true;
  end if;
  if p_what in ('players', 'all') then delete from participants where true; end if;
  update state set phase = 'idle', opened_at = null, revealed_correct = null, podium_step = 0, updated_at = now() where id = 1;
end $$;

grant execute on function hunt_guess(uuid, uuid, text), hunt_reveal(uuid, uuid), hunt_board(), hunt_submit(uuid, uuid, text, text, text) to anon, authenticated;

-- Day 2: no paper on the lake. Each team leader holds a printed WAP deck (the A, B and C cards).
update hunt_cards set prompt = regexp_replace(prompt, '^WAP explorer: find', 'WAP deck: find') where code like 'W%';
update hunt_cards set prompt = 'WAP deck: find the CESSPIT card in your team leader''s deck and scan it.' where code = 'W1';
update hunt_cards set prompt = 'WAP deck: find a latrine card that WAP counts as IMPROVED AND USABLE (two are right).' where code = 'W7';

do $$
declare v uuid; r record;
begin
  for r in select * from (values
    ('F1', 'Field task: find the nearest water point at the lake. Take a photo, and in the caption write which source card (B1–B6) describes it.'),
    ('F2', 'Field task: find a toilet at the lake. Photo, and in the caption: which latrine card (C1–C4) matches it, and why.'),
    ('F3', 'Field task: follow where a sink or toilet drains. Photo, and in the caption: which disposal card (A1–A8) it is.'),
    ('F4', 'Field task: count the bins you can see from your picnic spot. Photo, with the number in the caption (WAP M.1–M.8).')
  ) as t(code, prompt) loop
    if not exists (select 1 from hunt_cards where code = r.code) then
      insert into hunt_cards (code, position, kind, prompt, points) values (r.code, 100 + right(r.code, 1)::int, 'photo', r.prompt, 2) returning id into v;
      insert into hunt_keys (card_id, answer) values (v, '');
    end if;
  end loop;
end $$;
