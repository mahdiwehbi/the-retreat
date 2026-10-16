-- WASH Retreat, part 24: race result shows the 4-point bonus on its own line.
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
        'helps', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason like 'Word race help%'), 0),
        'crack', coalesce((select sum(points) from team_points p where p.team_id = t.id and p.reason in ('First to crack the secret word', 'Cracked the secret word')), 0)
      ) order by t.id), '[]'::json) from teams t));
end $$;
grant execute on function race_result() to anon, authenticated;
