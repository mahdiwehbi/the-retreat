-- WASH Retreat, part 8: the presenter runs by session.
-- The screen can show a session title card (what we do now, how long, what to do), keyed by
-- state.session_key. The session list itself lives in public/sessions.js.

alter table state add column if not exists session_key text;
alter table state drop constraint if exists state_screen_check;
alter table state add constraint state_screen_check
  check (screen in ('lobby', 'activity', 'leaderboard', 'teams', 'podium', 'hunt', 'session', 'sap'));

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
  if p_patch ? 'podium_step' then st.podium_step := greatest(0, least(3, (p_patch->>'podium_step')::int)); end if;
  update state set activity_id = st.activity_id, phase = st.phase, screen = st.screen,
    opened_at = st.opened_at, revealed_correct = st.revealed_correct,
    podium_step = st.podium_step, session_key = st.session_key, updated_at = now()
    where id = 1;
end $$;

grant execute on function host_set_state(text, jsonb) to anon, authenticated;
