// The retreat, session by session, in the lake theme ("Where the waters meet").
// title = the themed name; sub = what it really is. Each session owns the questions whose
// position falls in [from, to]. `opens` lists the QR groups that open when the presenter
// reaches the session (badges, rooms, lake, sap); groups stay open after that.
window.WR_THEME = { name: 'Where the Waters Meet', tagline: 'WASH Sector Coordination Team Retreat · Taanayel, 22–23 October 2026' };
window.WR_SESSIONS = [
  { key: 'd1-open', day: 1, label: 'Opening', time: '10:00–10:30', title: 'The Source', sub: 'Where were you?', from: 1, to: 4,
    show: ['Look at the map of Lebanon on the floor.', 'Stand where you were in the first week of the escalation (23 September 2024).', 'Say one sentence: what were you doing that day?', 'Then answer on your phone.'],
    host: ['Tape a rough outline of Lebanon on the floor: North, Beirut, BML, Bekaa, South.', 'Go round the room, one sentence each.', 'Keep the word cloud on screen during coffee.', 'Announce the 3 teams and the points system.'] },
  { key: 'd1-s1', day: 1, label: 'Session 1', time: '10:30–12:00', title: 'Upstream', sub: 'The war response: what really happened', from: 5, to: 8,
    show: ['Timeline wall: add sticky notes from your phone.', 'Green = worked · Red = broke down · Yellow = surprise.', 'Then dot vote the 3 notes that matter most.', 'Each team turns the top notes into Start / Stop / Continue.'],
    host: ['Optional opener: helium stick (5 min).', 'Timeline 40 min · dot vote 10 min · Start/Stop/Continue 30 min · read-out 10 min.', 'The final list becomes the lessons-learned note.'] },
  { key: 'd1-coffee', day: 1, label: 'Coffee break', time: '12:00–12:15', title: 'Water Break', sub: 'Quiz: how well do you know the war sheet?', from: 9, to: 18,
    show: ['10 quick questions from our own data.', 'Faster right answers score more.', 'Grab a coffee and keep your phone close.'],
    host: ['Each question opens, then reveals the answer and the top players.'] },
  { key: 'd1-s2', day: 1, label: 'Session 2', time: '12:15–13:05', title: 'Pipes & Pumps', sub: 'IM tools speed-dating', from: 19, to: 24,
    show: ['5 stations, one tool each. 6 minutes per station.', 'At each station your team writes one love, one pain and one wish.', 'Then vote on every tool: keep, fix or kill.'],
    host: ['Optional opener: data relay (broken telephone).', 'Station hosts give a 2-minute demo.', 'Run the 5 keep/fix/kill votes back to back.'] },
  { key: 'd1-s2b', day: 1, label: 'Session 2 · part 2', time: '13:05–13:20', title: 'Murky Waters', sub: 'Data detective: the Referrals tab', from: 25, to: 26,
    show: ['Each team gets a printed extract of the Referrals tab.', '8 minutes: find as many data problems as you can.', 'One point per problem.', 'Then: what should a future referral tool enforce?'],
    host: ['Problems to look for: spelling of villages, duplicates, blank status, costs as text.', 'Keep the wish list: it is the spec for the referral tool.'] },
  { key: 'd1-s3', day: 1, label: 'Session 3', time: '13:20–14:00', title: 'Flood Watch', sub: 'What if? Scenarios for the coming months', from: 27, to: 28,
    show: ['Each team opens its sealed scenario card.', '20 minutes: plan the first 72 hours.', 'Who coordinates what, what data on day 1, which IM product must be ready now.', 'Then score the other plans for realism.'],
    host: ['Optional opener: marshmallow challenge.', 'Card A renewed escalation · Card B funding cut · Card C return and recovery.'] },
  { key: 'd1-lunch', day: 1, label: 'Lunch', time: '14:00–15:00', title: 'Safe Harbour', sub: 'Lunch and room check-in', from: 0, to: -1, opens: ['rooms'],
    show: ['Lunch in the hotel restaurant.', 'Pick up your room key: a welcome card is waiting on your bed.', 'Scan it for a bonus question: 2 points for your team.', 'Back in the room at 15:00. Bring your badge.'],
    host: ['Reaching this card opens the room bonus cards.'] },
  { key: 'd1-race', day: 1, label: 'After lunch', time: '15:00', title: 'Message in a Bottle', sub: 'Word race: crack the secret word', from: 0, to: -1, screen: 'hunt', opens: ['badges'],
    show: ['Take out your name badge.', 'Scan it again and answer the question: 2 letters go to your team.', 'The 6 badges of a team spell the whole word.', 'First team to guess it wins 10 points.'],
    host: ['Reaching this card opens the badges: scanning now opens the question.', 'Next puts the race on the screen.'] },
  { key: 'd1-s4', day: 1, label: 'Session 4', time: '15:00–16:00', title: 'Deep Waters', sub: 'Informal settlements: Shark Tank', from: 29, to: 31,
    show: ['Each team designs one approach for informal settlements.', 'Herons: minimum service package · Kingfishers: cost-efficiency · Flamingos: exit and handover.', '3 minutes per pitch. Then invest your $100k.'],
    host: ['Optional opener: balloon and skewer.', 'Framing 10 min · build 25 min · pitch 15 min · wrap 10 min.'] },
  { key: 'd1-close', day: 1, label: 'Close of Day 1', time: '16:00', title: 'Sunset on the Shore', sub: 'One word, and tomorrow’s expedition', from: 32, to: 32,
    show: ['One word for how you leave today.', 'Rest in your rooms. We drive to Wadi Chamsine at 17:00.', 'Tomorrow at the lake: the expedition. Team leaders hold the deck.', 'Bring walking shoes and a charged phone.'],
    host: ['Hand the WAP decks, site cards and tent cards to the 3 team leaders.'] },
  { key: 'd2-breakfast', day: 2, label: 'Day 2 · Breakfast', time: '09:00–10:30', title: 'Morning Mist', sub: 'Tomorrow’s headline', from: 33, to: 33,
    show: ['Write the newspaper headline you want to read about the WASH response one year from now.'],
    host: ['The headlines come back at Chams.'] },
  { key: 'd2-lake', day: 2, label: 'Day 2 · Taanayel', time: '11:30–13:30', title: 'The Expedition', sub: 'WAP challenge and site test at the lake', from: 0, to: -1, screen: 'hunt', opens: ['lake', 'sap'],
    show: ['Part 1: WAP deck. For each clue, find the right card in your leader’s deck and scan it.', 'Every scan tells you what that card really is.', 'Part 2: site test. Fill the site form and the tent forms for your site.', 'The phone shows what you got wrong, with the WAP rule.'],
    host: ['Reaching this card opens the WAP deck, the field tasks and the site test.', 'Follow progress in Host → Site test (SAP).'] },
  { key: 'd2-debrief', day: 2, label: 'Day 2 · Chams', time: '14:00', title: 'Back to Shore', sub: 'Site test debrief', from: 34, to: 36,
    show: ['How easy was the form? Who collects on a big site?', 'The one thing to fix first.'],
    host: ['Show each team’s accuracy from Host → Site test (SAP).'] },
  { key: 'd2-awards', day: 2, label: 'Day 2 · Closing', time: '15:00', title: 'Ripples', sub: 'The Golden Drop awards and closing', from: 37, to: 41,
    show: ['Vote for the Golden Drop awards.', 'Then the final team scores and the podium.', 'The retreat in one word.'],
    host: ['After the last question: Team scores, then the podium.'] }
];
window.WR_SESSIONS.of = function (pos) { return window.WR_SESSIONS.find((s) => pos >= s.from && pos <= s.to) || null; };
window.WR_SESSIONS.get = function (key) { return window.WR_SESSIONS.find((s) => s.key === key) || null; };
