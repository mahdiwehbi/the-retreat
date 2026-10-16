-- WASH Retreat, part 5: Day 2 as WAP training.
-- Every answer gets feedback: a wrong WAP card explains what that card really is, and a
-- household form shows which answers differ from the tent card, with the WAP rule.

-- 1) What each WAP card really is (kept private; returned only after a scan) ----------------
create table if not exists hunt_spot_keys (
  code text primary key,
  name text not null,
  explain text not null
);
alter table hunt_spot_keys enable row level security;

insert into hunt_spot_keys (code, name, explain) values
  ('A1', 'Above ground', 'The pipe ends on the soil surface and wastewater stays exposed. WAP calls this "above ground".'),
  ('A2', 'Irrigation / stormwater channel', 'The latrine connects straight to a ditch or channel without any septic system.'),
  ('A3', 'Uncovered pit', 'A hole in the ground with no lining on the sides and no lid.'),
  ('A4', 'Covered pit', 'It has a lid, but the sides are not reinforced. A lid alone does not make it a cesspit.'),
  ('A5', 'Cesspit', 'Lined sides and a cover, but the base is not sealed: liquid leaches into the ground and solids are desludged.'),
  ('A6', 'Septic tank', 'A container with several chambers. Solids settle and the effluent overflows to a leach pit. A septic tank is pre-treatment, not treatment.'),
  ('A7', 'Holding tank', 'Fully sealed: nothing goes into the ground, so it fills up and must be emptied by truck.'),
  ('A8', 'Public network', 'Connected to the municipal or regional sewer, whether or not the wastewater is treated.'),
  ('A9', 'Cesspit', 'Tricky one: a holding tank with holes, or one connected to a cesspit, counts as a CESSPIT in WAP, because liquid leaks into the ground.'),
  ('B1', 'Public network', 'Piped from outside the site by the Water Establishment or municipality to a delivery point.'),
  ('B2', 'Protected borehole', 'Sealed at the surface with an apron and cap, and lined for the first metres underground.'),
  ('B3', 'Unprotected borehole', 'Open at the top with no slab or seal.'),
  ('B4', 'Protected spring', 'It has a spring tapping, a spring box, drainage AND a fence. All of them are needed.'),
  ('B5', 'Unprotected spring', 'Water flows out of the ground into an open pool. No box, no drainage, no fence.'),
  ('B6', 'Water trucking paid for by NGO', 'Trucked water is its own source. Who pays matters: NGO and occupants are separate options in W.16.'),
  ('B7', 'Unprotected borehole', 'Tricky one: the concrete apron is there, but the well is not capped or sealed underground. WAP needs both to call it protected.'),
  ('B8', 'Unprotected spring', 'Tricky one: it has a spring box, but no fence and no drainage, so WAP still counts it as unprotected.'),
  ('C1', 'Improved and usable', 'Durable walls, privacy (a lock), safety (light) and it works.'),
  ('C2', 'Not improved', 'Plastic sheeting on a frame is not a durable material, even if the pan works.'),
  ('C3', 'Not usable', 'Good walls, but a permanently blocked latrine is not usable.'),
  ('C4', 'Improved and usable', 'A latrine that needs maintenance (not rehabilitation) still counts as improved and usable.')
on conflict (code) do update set name = excluded.name, explain = excluded.explain;

insert into hunt_spots (code, grp, title, description, position) values
  ('A9', 'Blackwater disposal', 'Disposal A9', 'A plastic tank buried next to the latrine. Holes were drilled in its sides so it fills up more slowly.', 19),
  ('B7', 'Water source', 'Source B7', 'A drilled well with a concrete slab around it. The top is open and the casing stops at the surface.', 20),
  ('B8', 'Water source', 'Source B8', 'Water flows from the hillside into a concrete spring box. Goats drink around it; there is no fence and no drainage channel.', 21)
on conflict (code) do update set description = excluded.description, title = excluded.title, grp = excluded.grp;

do $$
declare v uuid; r record;
begin
  for r in select * from (values
    ('W8', 'Tricky: find the card that looks like a tank but WAP counts as a CESSPIT.', 'A9'),
    ('W9', 'Tricky: find the borehole with concrete that WAP still calls UNPROTECTED.', 'B7'),
    ('W10', 'Tricky: find the spring with a spring box that WAP still calls UNPROTECTED.', 'B8'),
    ('W11', 'Find the latrine card that is NOT IMPROVED because of its materials.', 'C2'),
    ('W12', 'Find the latrine card that is improved but NOT USABLE.', 'C3')
  ) as t(code, prompt, answer) loop
    if not exists (select 1 from hunt_cards where code = r.code) then
      insert into hunt_cards (code, position, kind, prompt, points) values (r.code, 40 + substr(r.code, 2)::int, 'find', r.prompt, 2) returning id into v;
      insert into hunt_keys (card_id, answer) values (v, r.answer);
    end if;
  end loop;
end $$;

-- 2) Scans now come back with an explanation ----------------------------------------------
create or replace function hunt_submit(p_pid uuid, p_token uuid, p_code text, p_answer text, p_photo text default null) returns json
language plpgsql security definer set search_path = public as $$
declare
  me participants; c hunt_cards; k text; ok boolean; v_wrong int; v_secret text; v_letter text; sk hunt_spot_keys;
begin
  me := _player(p_pid, p_token);
  select * into c from hunt_cards where upper(code) = upper(btrim(coalesce(p_code, '')));
  if not found then raise exception 'This card is not part of the game'; end if;
  select value into v_secret from secrets where key = 'hunt_secret';
  if c.letter_index is not null and c.letter_index >= 0 and c.letter_index < char_length(coalesce(v_secret, '')) then
    v_letter := substr(v_secret, c.letter_index + 1, 1);
  end if;
  if c.kind = 'find' then select * into sk from hunt_spot_keys where code = upper(btrim(coalesce(p_answer, ''))); end if;
  if exists (select 1 from hunt_finds where card_id = c.id and team_id = me.team_id and correct) then
    return json_build_object('status', 'already', 'letter', v_letter, 'position', c.letter_index, 'name', sk.name, 'explain', sk.explain);
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
  if ok then return json_build_object('status', 'correct', 'letter', v_letter, 'position', c.letter_index, 'points', c.points, 'name', sk.name, 'explain', sk.explain); end if;
  return json_build_object('status', 'wrong', 'left', case when c.letter_index is null then 2 - v_wrong else 99 end, 'name', sk.name, 'explain', sk.explain);
end $$;

-- 3) Household forms: feedback against the tent card -----------------------------------------
alter table sap_households add column if not exists first_data jsonb;

drop function if exists sap_save_household(uuid, uuid, text, jsonb, jsonb, timestamptz);
create or replace function sap_save_household(p_pid uuid, p_token uuid, p_tent text, p_data jsonb, p_kap jsonb, p_started timestamptz) returns json
language plpgsql security definer set search_path = public as $$
declare me participants; t sap_tents; tr jsonb; v_diff json; v_total int; v_right int;
begin
  me := _player(p_pid, p_token);
  select * into t from sap_tents where upper(code) = upper(btrim(coalesce(p_tent, '')));
  if not found then raise exception 'This tent card is not part of the test'; end if;
  if t.team_id <> me.team_id then raise exception 'This tent belongs to another team''s site'; end if;
  if length(coalesce(p_data, '{}'::jsonb)::text) > 10000 then raise exception 'Too long'; end if;
  insert into sap_households (team_id, tent_id, participant_id, data, first_data, kap, started_at)
    values (me.team_id, t.id, me.id, coalesce(p_data, '{}'::jsonb), coalesce(p_data, '{}'::jsonb), p_kap, p_started)
    on conflict (team_id, tent_id) do update set data = excluded.data, kap = excluded.kap,
      participant_id = excluded.participant_id, created_at = now(),
      first_data = coalesce(sap_households.first_data, excluded.first_data);
  select data into tr from sap_truth where tent_id = t.id;
  select count(*), count(*) filter (where coalesce(p_data->>k, '') = tr->>k),
         coalesce(json_agg(json_build_object('field', k, 'given', coalesce(p_data->>k, ''), 'expected', tr->>k)) filter (where coalesce(p_data->>k, '') <> tr->>k), '[]'::json)
    into v_total, v_right, v_diff from jsonb_object_keys(tr) as k;
  return json_build_object('status', 'ok', 'total', v_total, 'right', v_right, 'diff', v_diff);
end $$;

create or replace function host_sap_accuracy(p_pin text) returns json
language plpgsql stable security definer set search_path = public as $$
begin
  perform _need_host(p_pin);
  return (select coalesce(json_agg(json_build_object('team_id', tm.id, 'checked', x.checked, 'right', x.right_n) order by tm.id), '[]'::json)
    from teams tm left join lateral (
      select count(*) as checked, count(*) filter (where (coalesce(h.first_data, h.data)->>k.key) = (tr.data->>k.key)) as right_n
      from sap_households h join sap_truth tr on tr.tent_id = h.tent_id, jsonb_object_keys(tr.data) as k(key)
      where h.team_id = tm.id
    ) x on true);
end $$;

grant execute on function hunt_submit(uuid, uuid, text, text, text), sap_save_household(uuid, uuid, text, jsonb, jsonb, timestamptz), host_sap_accuracy(text) to anon, authenticated;
