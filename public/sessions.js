// The retreat, session by session, in the lake theme ("Where the waters meet").
// title = the themed name; sub = what it really is. Each session owns the questions whose
// position falls in [from, to]. `opens` / `closes` list QR groups that open or close when the
// presenter reaches the session; an opened group stays open until a later session closes it.
// Groups: register, badges, rooms, race, practice, sap, lake, feedback, closed.
window.WR_THEME = { name: 'Where the Waters Meet', tagline: 'WASH Sector Coordination Team Retreat · 22–23 October 2026' };
window.WR_SESSIONS = [
  { key: 'd1-open', day: 1, label: 'Opening', time: '10:00–10:30', title: 'The Source', sub: 'Welcome, attendance and where were you?', from: 1, to: 4, opens: ['register'],
    show: ['Look at the map of Lebanon on the floor.', 'Stand where you were in the first week of the escalation (2 March 2026).', 'Say one sentence: what were you doing that day?'],
    host: ['Registration is open: everyone scans their badge; names appear on the join screen. Next locks it (badges still work for latecomers).', 'Tape a rough outline of Lebanon on the floor: North, Beirut, BML, Bekaa, South.', 'Announce the 3 teams and the points system.'] },
  { key: 'd1-s1', day: 1, label: 'Session 1', time: '10:30–12:00', title: 'Upstream', sub: 'The war response: what really happened', from: 5, to: 8, closes: ['register'],
    show: ['Three flip charts on the wall: What worked well · What did not work · What surprised us.', 'Write one idea per sticky note and put it on the right flip chart, near its date on the timeline.', 'Then each team opens its sealed theme card: what would we do differently, and who owns it?', 'Each team presents. Then one personal reflection on your phone.'],
    host: ['Sticky notes and flip charts only: nothing on the phones until the theme cards.', 'Timeline 40 min · theme cards 20 min · presentations 3 min per team (the wheel picks the order) · reflection 5 min.', 'Theme cards: Herons coordination and information · Kingfishers delivery in collective shelters · Flamingos partners, government and Water Establishments.'] },
  { key: 'd1-coffee', day: 1, label: 'Coffee break', time: '12:00–12:15', title: 'Water Break', sub: 'Quiz: how well do you know our response dashboard?', from: 9, to: 18,
    show: ['Quick questions from our own dashboard (ActivityInfo reporting since 2 March 2026).', 'Faster right answers score more.', 'Grab a coffee and keep your phone close.'],
    host: ['Each question opens, then reveals the answer and the top players.'] },
  { key: 'd1-s2', day: 1, label: 'Session 2', time: '12:15–13:05', title: 'Pipes & Pumps', sub: 'IM tools speed-dating', from: 19, to: 24,
    show: ['5 stations: War sheet (booking) · Referral sheet · ActivityInfo · RTA · QR tracking.', '6 minutes per station. Your team writes one love, one pain and one wish.', 'Then vote on every tool: keep, fix or kill.'],
    host: ['Station hosts give a 2-minute demo.', 'Run the 5 keep/fix/kill votes back to back.'] },
  { key: 'd1-s2b', day: 1, label: 'Session 2 · part 2', time: '13:05–13:20', title: 'Murky Waters', sub: 'Data detective: the 2026 Referrals tab', from: 25, to: 25,
    show: ['Each team gets a printed extract of the 2026 Referrals tab.', '8 minutes: find as many data problems as you can.', 'Write the problems, then your suggestions for a future referral tool.', 'The wheel picks who presents first.'],
    host: ['The facilitator key is the last page of the extract printout.'] },
  { key: 'd1-s3', day: 1, label: 'Session 3', time: '13:20–14:00', title: 'Flood Watch', sub: 'What if? Scenarios for the coming months', from: 27, to: 27,
    show: ['Each team opens its sealed scenario card: renewed escalation, protracted crisis, or return and recovery.', '20 minutes. Fill three pages: who coordinates what, the IM tools we need, and the lessons from this morning we apply.', 'The wheel picks who presents first.'],
    host: ['No scoring: just the plans and the discussion.'] },
  { key: 'd1-lunch', day: 1, label: 'Lunch', time: '14:00–15:00', title: 'Safe Harbour', sub: 'Lunch, room check-in and your two questions', from: 0, to: -1, opens: ['rooms', 'badges'], card: true,
    show: ['A welcome card is waiting on your bed, with 4 times to tick.', 'Scan your badge and your room card: each has a question.', 'Each question opens 1 letter of a secret message. 3 tries each.', 'Back in the meeting room at 15:00 sharp.'],
    host: ['Reaching this card opens the badge and room questions. People without a room answer 2 questions on their badge.'] },
  { key: 'd1-race', day: 1, label: 'After lunch', time: '15:00', title: 'Message in a Bottle', sub: 'Word race: crack the secret message', from: 0, to: -1, screen: 'hunt', opens: ['race'],
    show: ['Sit with your team. Open Treasure hunt on your phone.', 'Your letters are at the top. Tap a letter, then tap a box: everyone in your team sees it.', 'Stuck? Each person can use 1 help (minus 1 point): it puts one of your letters in its right place.', 'Anyone can submit the message for the team. First team to crack it wins 10 points.'],
    host: ['Next puts the race on the screen.'] },
  { key: 'd1-s4', day: 1, label: 'Session 4', time: '15:15–15:30', title: 'Deep Waters', sub: 'Informal settlements: where we stand, what we need', from: 29, to: 30,
    show: ['Plenary discussion.', 'Where does the sector stand on informal settlements today?', 'What do we need?'],
    host: ['Plenary: no phones needed.'] },
  { key: 'd1-brief', day: 1, label: 'Session 4 · part 2', time: '15:30–15:40', title: 'Tomorrow’s Expedition', sub: 'How tomorrow’s WAP exercise works', from: 0, to: -1, opens: ['practice', 'lake'], demo: true,
    show: ['Each team leader gets: 1 site card, 3 tent cards and the helper cards.', 'First fill the site form, then one household form per tent.', 'Tent and site cards point to helper cards (A, B, C): scan the helper card to see its WAP name.', 'Each tent form tells you right away what you got wrong, with the WAP rule. Let’s practise one tent now.'],
    host: ['Next plays the demo on the screen, step by step (7 steps). Then scan the practice tent card yourself: it does not count.'] },
  { key: 'd1-eoy', day: 1, label: 'Session 5', time: '15:40–16:00', title: 'The Next Current', sub: 'End-of-Year WaSH Sector Workshop Planning', from: 31, to: 32,
    show: ['Discuss, prioritise and agree on the key themes and sessions of our end-of-year workshop.', 'On the table: water quality · emergency response · sector transition.', 'Then on your phone: tick what we should cover, and tell us what we missed.'],
    host: ['20 minutes: discuss the three themes, then open the question. Agree the themes before Sunset on the Shore.'] },
  { key: 'd1-close', day: 1, label: 'Close of Day 1', time: '16:00', title: 'Sunset on the Shore', sub: 'One word, and the plan for tonight', from: 33, to: 33, closes: ['practice'],
    show: ['One word for how you leave today.', 'Rest in your rooms. Be down at 17:00 sharp: we drive to Wadi Chamsine.', 'Tomorrow: breakfast 08:00–10:00, check out by 10:00. We move at 10:30 sharp to Taanayel.'],
    host: ['Hand the site cards, tent cards and helper cards to the 3 team leaders.'] },
  { key: 'd2-lake', day: 2, label: 'Day 2 · Taanayel', time: '11:00–13:30', title: 'The Expedition', sub: 'WAP test at the lake, then feedback', from: 0, to: -1, opens: ['sap', 'feedback'],
    show: ['Fill the site form, then the 3 tent forms.', 'Scan a helper card to see what it is.', 'When you are done: the feedback form on your phone.'],
    host: ['No screen on Day 2: open this from your phone (Host → Run → Next) before the lake, or the night before.'] }
];
window.WR_SESSIONS.of = function (pos) { return window.WR_SESSIONS.find((s) => pos >= s.from && pos <= s.to) || null; };
window.WR_SESSIONS.get = function (key) { return window.WR_SESSIONS.find((s) => s.key === key) || null; };
