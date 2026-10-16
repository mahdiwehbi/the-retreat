-- WASH Retreat, part 18: a name badge always checks its owner in, even after registration closed.
-- Only the generic join (no badge) stays locked.

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
