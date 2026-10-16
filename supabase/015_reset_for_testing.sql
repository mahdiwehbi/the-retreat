-- Reset everything before testing (same as Host → Reset → Reset everything), and start on the join screen.
delete from responses where true; delete from notes where true; delete from note_votes where true; delete from team_entries where true;
delete from team_points where true;
delete from hunt_finds where true; delete from hunt_guesses where true;
delete from assessments where true; delete from sap_households where true; delete from sap_sites where true;
delete from participants where true;
update state set activity_id = null, phase = 'idle', screen = 'lobby', opened_at = null, revealed_correct = null,
  podium_step = 0, session_key = null, live = array['register'], hunt_live = false, updated_at = now() where id = 1;
