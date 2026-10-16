-- WASH Retreat, part 12: optional room numbers on the room welcome cards.
-- Empty room = the card prints without a room line.
alter table hunt_cards add column if not exists room text not null default '';

create or replace function host_save_card(p_pin text, p_id uuid, p_data jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid := p_id;
begin
  perform _need_host(p_pin);
  if v_id is null then
    insert into hunt_cards (code, position, kind, prompt, options, letter_index, letter_index2, team_id, holder, points, golden) values (
      upper(coalesce(nullif(btrim(p_data->>'code'), ''), substr(md5(random()::text), 1, 5))),
      coalesce((p_data->>'position')::int, (select coalesce(max(position), 0) + 1 from hunt_cards)),
      coalesce(p_data->>'kind', 'text'), coalesce(p_data->>'prompt', ''),
      coalesce(p_data->'options', '[]'::jsonb), nullif(p_data->>'letter_index', '')::int, nullif(p_data->>'letter_index2', '')::int,
      nullif(p_data->>'team_id', '')::int, left(coalesce(p_data->>'holder', ''), 60),
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
      letter_index2 = case when p_data ? 'letter_index2' then nullif(p_data->>'letter_index2', '')::int else letter_index2 end,
      team_id = case when p_data ? 'team_id' then nullif(p_data->>'team_id', '')::int else team_id end,
      holder = case when p_data ? 'holder' then left(coalesce(p_data->>'holder', ''), 60) else holder end,
      room = case when p_data ? 'room' then left(btrim(coalesce(p_data->>'room', '')), 20) else room end,
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

grant execute on function host_save_card(text, uuid, jsonb) to anon, authenticated;
