-- WASH Retreat, part 33: The Source as a partner interview (the name on the back of your badge).
update activities set title = 'Where was your partner in the first week of the escalation (2 March 2026)?' where position = 1;
update activities set title = 'Your partner''s story in one sentence: their name and what they were doing that first day.' where position = 2;
select position, kind, title from activities where position between 1 and 4 order by position;
