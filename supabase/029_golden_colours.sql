-- WASH Retreat, part 29: the golden photo is a find-the-place challenge at Taanayel lake.
-- Each team sees only its own line (card.html picks the line that starts with the team name).
update hunt_cards set prompt = 'Golden card: find the spot at Taanayel and take a photo of your whole team there.
Herons: the background must be black and white (hint: the farm).
Kingfishers: the background must be green and blue (hint: the water and the trees).
Flamingos: the background must have a bird on the water (hint: look along the shore).'
where code = 'G1';
