-- WASH Retreat, part 17: the two Referrals quiz questions use the 2026 war sheet (55 referrals).
do $$
declare v uuid;
begin
  select id into v from activities where position = 17 and kind = 'quiz';
  if v is not null then
    update activities set title = 'Which referral type has the most rows in the 2026 Referrals tab?', options = '["Generators", "Solar farms / panels (station level)", "Water network", "Civil works"]'::jsonb where id = v;
    insert into activity_keys (activity_id, correct) values (v, 0) on conflict (activity_id) do update set correct = excluded.correct;
    delete from responses where activity_id = v;
  end if;
  select id into v from activities where position = 18 and kind = 'quiz';
  if v is not null then
    update activities set title = 'Of the 55 referrals in the 2026 sheet, how many have a cost estimate?', options = '["None", "About 10", "About 30", "All of them"]'::jsonb where id = v;
    insert into activity_keys (activity_id, correct) values (v, 0) on conflict (activity_id) do update set correct = excluded.correct;
    delete from responses where activity_id = v;
  end if;
end $$;
