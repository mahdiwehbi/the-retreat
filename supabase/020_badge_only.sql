-- WASH Retreat, part 20: people join only with their name badge. The open join is switched off.
create or replace function join_retreat(p_name text, p_team int default null) returns json
language plpgsql security definer set search_path = public as $$
begin
  raise exception 'Join by scanning the QR code on your name badge.';
end $$;
grant execute on function join_retreat(text, int) to anon, authenticated;
