"""Builds supabase/003_content.sql: every retreat exercise, the hunt and the SAP test sites.

Run: python3 supabase/make_content.py  (writes 003_content.sql next to this file)
The quiz figures come from the WaSH Sector Response Planning (2024 war) sheet.
"""
import json
import random
from pathlib import Path

OUT = Path(__file__).with_name('003_content.sql')


def q(s):
    return "'" + str(s).replace("'", "''") + "'"


def j(o):
    return q(json.dumps(o, ensure_ascii=False)) + '::jsonb'


acts = []  # (kind, title, options, extra)


def add(kind, title, options=None, correct=None, time_limit=20, max_words=3):
    acts.append(dict(kind=kind, title=title, options=options if options is not None else [], correct=correct,
                     time_limit=time_limit, max_words=max_words))
    return len(acts)


KFK = ['Keep', 'Fix', 'Kill']

# ---------------- Day 1 · Opening ----------------
add('poll', 'Where were you in the first week of the escalation (23 September 2024)?',
    ['Beirut', 'Mount Lebanon', 'South / Nabatieh', 'Bekaa / Baalbek-Hermel', 'North / Akkar', 'Outside Lebanon'])
add('open', 'What were you doing that first day? One sentence.')
add('words', 'The war response in one word', max_words=1)
add('rating', 'Energy check: how are you arriving today?', ['Running on empty', 'Fully charged'])

# ---------------- Session 1 · The war response ----------------
board = add('board', 'Timeline wall: what happened during the war response', {
    'columns': ['Before 23 Sept: preparedness', 'First 72 hours', 'Collective shelters (Oct)',
                'Water trucking and supplies', 'South and system damage', 'Ceasefire 27 Nov and returns',
                '2025: recovery'],
    'tags': ['Worked', 'Broke down', 'Surprise']})
add('dots', 'Dot vote: the 3 notes that matter most', {'board_pos': board, 'dots': 3})
add('team', 'Start / Stop / Continue: coordination lessons', {'fields': [
    {'label': 'What we start, stop and continue', 'type': 'list', 'tags': ['Start', 'Stop', 'Continue']},
    {'label': 'Our top lesson in one sentence', 'type': 'text'}]})
add('open', 'One lesson from the war you will never forget')

# ---------------- Coffee quiz (from the war sheet) ----------------
add('quiz', 'Between 23 Sept and 25 Nov 2024, how many collective shelters got WASH support recorded in the war sheet?',
    ['About 450', 'About 750', 'About 1,150', 'About 1,600'], 2)
add('quiz', 'How many partners reported WASH quantities in collective shelters?', ['23', '47', '81', '120'], 2)
add('quiz', 'Bottled water distributed to collective shelters?',
    ['About 190,000 litres', 'About 1.9 million litres', 'About 9 million litres', 'About 19 million litres'], 1)
add('quiz', 'Water trucked to collective shelters?', ['About 4,700 m³', 'About 47,000 m³', 'About 470,000 m³', 'About 4.7 million m³'], 1)
add('quiz', 'Family hygiene kits distributed?', ['About 8,000', 'About 25,000', 'About 82,000', 'About 150,000'], 2)
add('quiz', 'Which day has the most response records in the sheet?', ['23 September', '6 October', '27 October', '27 November'], 1)
add('quiz', 'Which district hosted the most IDPs (DTM round 66)?', ['Beirut', 'Saida', 'Aley', 'Chouf'], 2)
add('quiz', 'Which governorate had the most collective shelters listed?', ['Beirut', 'Mount Lebanon', 'South', 'Bekaa'], 1)
add('quiz', 'Which referral type has the most rows in the Referrals tab?',
    ['Solar farms / panels (station level)', 'Chlorination system', 'Public drinking point', 'Water network'], 0)
add('quiz', 'Of the 241 referrals, how many have no status filled in?', ['About 30', 'About 70', 'About 130', 'About 200'], 2)

# ---------------- Session 2 · IM tools ----------------
TOOLS = ['3W / ActivityInfo reporting', 'Referrals tab', 'Gap and PIN analysis', 'Collective shelter tabs',
         'Focal points and WhatsApp flow']
add('team', 'IM tools speed-dating: love, pain, wish', {'fields': [
    {'label': t, 'type': 'list', 'tags': ['Love', 'Pain', 'Wish']} for t in TOOLS]})
for t in TOOLS:
    add('poll', f'{t}: keep, fix or kill?', KFK)
add('team', 'Data detective: problems in the Referrals tab', {'fields': [
    {'label': 'Problems we found (1 point each)', 'type': 'list',
     'tags': ['Location / P-code', 'Status or partner', 'Duplicate', 'Cost', 'Other']}]})
add('team', 'Referral tool wish list', {'fields': [
    {'label': 'Rules the new referral tool must follow', 'type': 'list'}]})

# ---------------- Session 3 · What if? ----------------
add('team', 'What if? Our 72-hour plan', {
    'prompts': ['Card A · Renewed escalation: mass displacement in 48 hours, collective shelters reopen.',
                'Card B · Protracted crisis: funding cut by half, partners leaving.',
                'Card C · Return and recovery: people go home to damaged water networks.'],
    'fields': [
        {'label': 'First 72 hours: what happens, hour by hour', 'type': 'text'},
        {'label': 'Who coordinates what', 'type': 'list'},
        {'label': 'Data we need on day 1', 'type': 'list'},
        {'label': 'The one IM product we must have ready now', 'type': 'text'}]})
add('allocate', 'Score the plans: give 10 points for realism', {'items': [], 'budget': 10})

# ---------------- Session 4 · Informal settlements ----------------
add('rating', 'Where does the sector stand on informal settlements today?', ['Lost', 'On track'])
add('team', 'Shark Tank: our approach for informal settlements', {
    'prompts': ['Angle · Minimum service package and standards',
                'Angle · Cost-efficiency: from trucking to sustainable options',
                'Angle · Exit and handover to municipalities and Water Establishments'],
    'fields': [
        {'label': 'Our idea in one sentence', 'type': 'text'},
        {'label': 'What we would do', 'type': 'list'},
        {'label': 'Cost and who pays', 'type': 'text'},
        {'label': 'Exit: who takes over, and when', 'type': 'text'}]})
add('allocate', 'Invest your $100k: which pitch gets your money?', {'items': [], 'budget': 100})
add('words', 'One word for how you leave today', max_words=1)

# ---------------- Day 2 ----------------
add('team', "Tomorrow's headline: the WASH response one year from now", {'fields': [
    {'label': 'Our headline', 'type': 'text'},
    {'label': 'What we do to make it true', 'type': 'list'}]})
add('rating', 'Site test: how easy was the household form?', ['Very hard', 'Very easy'])
add('poll', 'Big site, 1 collector or a team of collectors?', ['1 collector, one tablet', '2–3 collectors', 'Whole team, one per household'])
add('open', 'The one thing to fix first in the site assessment tool')
for award in ['Best Excel Survivor', 'Fastest WhatsApp Reply', 'Calmest Under Pressure', 'Best Map Never Printed']:
    add('poll', award, ['Nominee 1', 'Nominee 2', 'Nominee 3'])
add('words', 'The retreat in one word', max_words=1)

# ---------------- Hunt: spot cards (WAP definitions) ----------------
spots = []  # code, grp, title, description


def spot(code, grp, title, desc):
    spots.append((code, grp, title, desc))
    return code


BW = 'Blackwater disposal'
s_above = spot('A1', BW, 'Disposal A1', 'The latrine pipe ends at the ground surface. Wastewater lies exposed on the soil.')
spot('A2', BW, 'Disposal A2', 'The latrine pipe goes straight into a ditch that drains the fields.')
spot('A3', BW, 'Disposal A3', 'A hole dug in the ground. No lining on the sides, no lid.')
spot('A4', BW, 'Disposal A4', 'A hole dug in the ground with a lid on top. The sides are not reinforced.')
s_cess = spot('A5', BW, 'Disposal A5', 'A hole with block walls and a concrete cover. The base is not sealed: liquid soaks into the soil, solids are desludged.')
s_septic = spot('A6', BW, 'Disposal A6', 'A container with two chambers. Solids settle, and an overflow pipe takes the effluent to a leach pit.')
s_hold = spot('A7', BW, 'Disposal A7', 'A fully sealed container. Nothing leaks into the ground; it must be emptied by truck.')
spot('A8', BW, 'Disposal A8', 'The latrine is connected to the municipal sewer line.')
WS = 'Water source'
spot('B1', WS, 'Source B1', 'Water arrives through pipes from the Water Establishment to a tap at the site entrance.')
spot('B2', WS, 'Source B2', 'A drilled well with a concrete apron, capped and sealed for the first metres.')
s_unprot_bh = spot('B3', WS, 'Source B3', 'A dug well, open at the top, with no slab around it.')
s_prot_spring = spot('B4', WS, 'Source B4', 'Water flows from the ground into a fenced spring box with a drainage channel.')
spot('B5', WS, 'Source B5', 'Water flows out of the ground into an open pool used by animals too.')
spot('B6', WS, 'Source B6', 'A truck fills the tanks twice a week; an NGO pays for it.')
LT = 'Latrine'
s_lat_ok1 = spot('C1', LT, 'Latrine C1', 'Block walls, a door that locks from inside, a light, and a working pour-flush pan.')
spot('C2', LT, 'Latrine C2', 'Walls of plastic sheeting on a wooden frame. The pan works.')
spot('C3', LT, 'Latrine C3', 'Concrete walls and a door, but the pit has been blocked for months.')
s_lat_ok2 = spot('C4', LT, 'Latrine C4', 'Concrete walls and a lockable door; the door hinge needs a small repair.')

# ---------------- Hunt: Day 1 hotel rooms, one letter per room ----------------
SECRET = 'WATERISLIFEFORALL'  # 17 letters for 17 rooms
cards = []  # code, kind, prompt, options, answer, letter, points, golden


def card(code, kind, prompt, answer='', options=None, letter=None, points=1, golden=False):
    cards.append((code, kind, prompt, options or [], answer, letter, points, golden))


ROOMS = [
    ('quiz', 'On which day did the 2024 escalation start?', ['23 September 2024', '8 October 2023', '1 October 2024', '27 November 2024'], '0'),
    ('text', 'On which date did the ceasefire start? (day and month)', None, '27 November|27 Nov|27/11|27-11|Nov 27|November 27'),
    ('text', 'Which district hosted the most IDPs after the war (DTM round 66)?', None, 'Aley|Alay|عاليه'),
    ('quiz', 'Which governorate had the most collective shelters listed?', ['Beirut', 'Mount Lebanon', 'South', 'Bekaa'], '1'),
    ('quiz', 'How many partners reported WASH quantities in collective shelters?', ['23', '47', '81', '120'], '2'),
    ('quiz', 'How much water was trucked to collective shelters?', ['About 4,700 m³', 'About 47,000 m³', 'About 470,000 m³', 'About 4.7 million m³'], '1'),
    ('quiz', 'Who raised most of the referrals in the Referrals tab?', ['Water Establishments', 'Municipalities', 'NGOs', 'UNICEF'], '0'),
    ('quiz', 'How many referrals carry the emergency tag "War"?', ['12', '45', '98', '150'], '1'),
    ('quiz', 'Which day has the most response records in the war sheet?', ['23 September', '6 October', '27 October', '27 November'], '1'),
    ('quiz', 'Roughly how much bottled water went to collective shelters?', ['190,000 litres', '1.9 million litres', '9 million litres', '19 million litres'], '1'),
    ('quiz', 'In WAP, a fully sealed container that releases nothing into the ground is a…', ['Holding tank', 'Cesspit', 'Septic tank', 'Covered pit'], '0'),
    ('quiz', 'In WAP, what does "one barrel" mean?', ['100 litres', '200 litres', '500 litres', '1,000 litres'], '1'),
    ('quiz', 'Residents call a tank "five barrels". How big is it?', ['500 litres', '1,000 litres', '2,000 litres', '5,000 litres'], '1'),
    ('quiz', 'The shawish refuses the assessment. What do you select in L.13?', ['Empty site', 'Active site', 'Refused to continue', 'Leave it blank'], '2'),
    ('quiz', 'WAP E.5 asks about public health concerns within…', ['100 m', '250 m', '500 m', '1 km'], '2'),
    ('quiz', 'How many critical times for handwashing does the KAP ask about?', ['3', '4', '5', '7'], '2'),
    ('quiz', 'A latrine needs maintenance but not rehabilitation. In WAP it is…', ['Improved and usable', 'Not improved', 'Not usable', 'Not counted'], '0'),
]
for k, (kind, prompt, options, answer) in enumerate(ROOMS):
    card(f'R{k + 1:02d}', kind, prompt, answer, options, letter=k)

# ---------------- Hunt: Day 2 lake, WAP explorer (points, no letters) ----------------
card('W1', 'find', "WAP deck: find the CESSPIT card in your team leader's deck and scan it.", s_cess, points=2)
card('W2', 'find', 'WAP deck: find the HOLDING TANK.', s_hold, points=2)
card('W3', 'find', 'WAP deck: find the SEPTIC TANK.', s_septic, points=2)
card('W4', 'find', 'WAP deck: find the disposal WAP calls "above ground".', s_above, points=2)
card('W5', 'find', 'WAP deck: find a PROTECTED SPRING.', s_prot_spring, points=2)
card('W6', 'find', 'WAP deck: find the UNPROTECTED BOREHOLE.', s_unprot_bh, points=2)
card('W7', 'find', 'WAP deck: find a latrine card that WAP counts as IMPROVED AND USABLE (two are right).', s_lat_ok1 + '|' + s_lat_ok2, points=2)
for code, prompt in [
    ('F1', 'Field task: find the nearest water point at the lake. Take a photo, and in the caption write which source card (B1–B6) describes it.'),
    ('F2', 'Field task: find a toilet at the lake. Photo, and in the caption: which latrine card (C1–C4) matches it, and why.'),
    ('F3', 'Field task: follow where a sink or toilet drains. Photo, and in the caption: which disposal card (A1–A8) it is.'),
    ('F4', 'Field task: count the bins you can see from your picnic spot. Photo, with the number in the caption (WAP M.1–M.8).')]:
    card(code, 'photo', prompt, points=2)
card('G1', 'photo', 'Golden card: a team photo that shows a real WASH risk around the lake.', points=3, golden=True)
card('G2', 'photo', 'Golden card: leaky-cup relay. Photo of your team with the filled bottle.', points=3, golden=True)

# ---------------- SAP test: three sites with tent cards ----------------
random.seed(2026)
SIZES = [80, 200, 500, 1000, 2000]
SRC = ['Public network', 'Protected borehole', 'Unprotected borehole', 'Water trucking (NGO)',
       'Water trucking (occupants)', 'Bottled water']
GREY = ['Above ground', 'Irrigation / stormwater channel', 'Uncovered pit', 'Covered pit', 'Cesspit',
        'Septic tank', 'Holding tank', 'Public network']
tents = []  # code, team, number, card text, truth


def household(n):
    # Ages listed one by one, so collectors must apply the WAP cut-offs (under 18; 60 or more).
    size = random.randint(3, 9)
    ages = [random.choice([62, 65, 70, 60, 59])] if random.random() < 0.45 else []
    ages += [random.randint(19, 45) for _ in range(random.choice([1, 2, 2]))]
    if random.random() < 0.5:
        ages.append(18)
    while len(ages) < size:
        ages.append(random.choice([17, 16, 12, 9, 7, 5, 3, 1]))
    ages = sorted(ages[:size], reverse=True)
    children = sum(a < 18 for a in ages); elderly = sum(a >= 60 for a in ages); adults = size - children - elderly
    tanks = {s: 0 for s in SIZES}
    for _ in range(random.choice([1, 1, 2, 2, 3])):
        tanks[random.choice([200, 500, 500, 1000, 1000, 2000])] += 1
    jerry = random.choice([0, 0, 2, 3, 4])
    shared = random.choice(['No', 'No', 'No', 'Yes'])
    drink = random.choice(['Bottled water', 'Bottled water', 'Water trucking (NGO)', 'Public network'])
    domestic = random.choice(['Water trucking (NGO)', 'Water trucking (NGO)', 'Protected borehole', 'Water trucking (occupants)', 'Unprotected borehole'])
    pays = 'Yes' if 'occupants' in domestic or drink == 'Bottled water' else random.choice(['No', 'No', 'Yes'])
    grey = random.choice(['Above ground', 'Above ground', 'Uncovered pit', 'Covered pit', 'Cesspit', 'Irrigation / stormwater channel'])
    lat_inside = random.choice(['Yes', 'No', 'No'])
    lat_state = random.choice(['ok', 'maintenance', 'blocked']) if lat_inside == 'Yes' else None
    lat_ok = 'Yes' if lat_state in ('ok', 'maintenance') else 'No'
    female = random.choice(['No', 'No', 'No', 'Yes'])
    disab = random.choice([0, 0, 0, 1])
    soap = random.choice(['Yes', 'Yes', 'No'])
    truth = {'members': str(size), 'children': str(children), 'adults': str(adults), 'elderly': str(elderly),
             'female_headed': female, 'disability': str(disab), 'shared_tank': shared, 'drink_source': drink,
             'domestic_source': domestic, 'pays_water': pays, 'greywater': grey, 'latrine_inside': lat_inside,
             'latrine_ok': lat_ok, 'soap': soap}
    for sz in SIZES:
        truth['tank_' + str(sz)] = str(tanks[sz])
    say = {200: 'a one-barrel tank', 500: 'a 500 L tank', 1000: 'a "five barrel" tank', 2000: 'a 2 m³ tank'}
    tank_parts = []
    for sz, c in tanks.items():
        if c:
            tank_parts.append(say[sz] if c == 1 else f'{c} × {say[sz][2:]}' if sz != 1000 else f'{c} "five barrel" tanks')
    tank_txt = ', '.join(tank_parts) or 'no tanks'
    src = {'Bottled water': 'bottled water they buy', 'Water trucking (NGO)': 'a truck an NGO pays for',
           'Public network': 'the network tap at the entrance', 'Protected borehole': 'the capped, sealed borehole with a slab',
           'Water trucking (occupants)': 'a truck the families pay for themselves', 'Unprotected borehole': 'an open dug well'}
    lines = [
        f'{size} people live here, aged ' + ', '.join(map(str, ages)) + '.',
        'A widow heads this household.' if female == 'Yes' else 'The father heads this household.',
        f'{disab} member uses a wheelchair.' if disab else 'Nobody has a physical disability.',
        f'Storage at the tent: {tank_txt}' + (f', plus {jerry} jerrycans of 20 L.' if jerry else '.') + (' One tank is shared with the neighbours.' if shared == 'Yes' else ''),
        f'They drink {src[drink]}; for washing they use {src[domestic]}.',
        'They pay for their water.' if pays == 'Yes' else 'They pay nothing for water.',
        {'Above ground': 'Kitchen and shower water runs out onto the ground behind the tent.',
         'Uncovered pit': 'Kitchen and shower water goes into an open hole next to the tent.',
         'Covered pit': 'Kitchen and shower water goes into a hole with a wooden lid; the sides are bare soil.',
         'Cesspit': 'Kitchen and shower water goes into a block-lined, covered pit with an open base, desludged twice a year.',
         'Irrigation / stormwater channel': 'Kitchen and shower water flows into the irrigation ditch.'}[grey],
        {'ok': 'Inside the shelter: a latrine with a pour-flush pan that works.',
         'maintenance': 'Inside the shelter: a latrine of plastic sheeting; the pan works but the door hinge needs fixing.',
         'blocked': 'Inside the shelter: a block-walled latrine, blocked for weeks.', None: 'No latrine inside the shelter; they use the shared latrines.'}[lat_state],
        'Soap is at the handwashing point.' if soap == 'Yes' else 'There is no soap at the handwashing point.'
    ]
    return truth, ' '.join(lines)


for team in (1, 2, 3):
    for n in range(1, 11):
        truth, text = household(n)
        tents.append((f'T{team}{n:02d}', team, n, text, truth))

# ---------------- SQL ----------------
L = ['-- Generated by make_content.py. Replaces all questions, hunt cards, spot cards and SAP tents.',
     '-- Clears answers given so far. Players and team points stay.', '',
     'delete from note_votes where true;', 'delete from notes where true;', 'delete from team_entries where true;',
     'delete from responses where true;', 'update state set activity_id = null, phase = \'idle\', screen = \'lobby\', opened_at = null, revealed_correct = null where id = 1;',
     'delete from activities where true;', 'delete from hunt_finds where true;', 'delete from hunt_cards where true;',
     'delete from hunt_spots where true;', 'delete from sap_households where true;', 'delete from sap_sites where true;',
     'delete from sap_tents where true;', '']
L.append('do $$\ndeclare ids uuid[] := array[]::uuid[]; v uuid;\nbegin')
for i, a in enumerate(acts, 1):
    opts = a['options']
    if a['kind'] == 'dots':
        opts = {'dots': opts['dots']}
    L.append(f"  insert into activities (position, kind, title, options, time_limit, max_words) values ({i}, {q(a['kind'])}, {q(a['title'])}, {j(opts)}, {a['time_limit']}, {a['max_words']}) returning id into v; ids := ids || v;")
    if a['correct'] is not None:
        L.append(f"  insert into activity_keys (activity_id, correct) values (v, {a['correct']});")
for i, a in enumerate(acts, 1):
    if a['kind'] == 'dots':
        L.append(f"  update activities set options = options || jsonb_build_object('board', ids[{a['options']['board_pos']}]::text) where id = ids[{i}];")
L.append('end $$;\n')
for k, (code, grp, title, desc) in enumerate(spots, 1):
    L.append(f"insert into hunt_spots (code, grp, title, description, position) values ({q(code)}, {q(grp)}, {q(title)}, {q(desc)}, {k});")
L.append('')
L.append('do $$\ndeclare v uuid;\nbegin')
for k, (code, kind, prompt, options, answer, letter, points, golden) in enumerate(cards, 1):
    L.append(f"  insert into hunt_cards (code, position, kind, prompt, options, letter_index, points, golden) values ({q(code)}, {k}, {q(kind)}, {q(prompt)}, {j(options)}, {'null' if letter is None else letter}, {points}, {'true' if golden else 'false'}) returning id into v;")
    L.append(f"  insert into hunt_keys (card_id, answer) values (v, {q(answer)});")
L.append('end $$;\n')
L.append(f"insert into secrets (key, value) values ('hunt_secret', {q(SECRET)}) on conflict (key) do update set value = excluded.value;\n")
L.append('do $$\ndeclare v uuid;\nbegin')
for code, team, n, text, truth in tents:
    L.append(f"  insert into sap_tents (code, team_id, number, card) values ({q(code)}, {team}, {n}, {q(text)}) returning id into v;")
    L.append(f"  insert into sap_truth (tent_id, data) values (v, {j(truth)});")
L.append('end $$;')
OUT.write_text('\n'.join(L) + '\n', encoding='utf-8')
U = ['-- Generated by make_content.py: refreshes the tent cards and their truth without touching anything else.',
     'delete from sap_households where true;']
for code, team, n, text, truth in tents:
    U.append(f"update sap_tents set card = {q(text)} where code = {q(code)};")
    U.append(f"update sap_truth set data = {j(truth)} where tent_id = (select id from sap_tents where code = {q(code)});")
OUT.with_name('006_tents.sql').write_text('\n'.join(U) + '\n', encoding='utf-8')
print(f'{len(acts)} activities, {len(spots)} spot cards, {len(cards)} clues, {len(tents)} tents -> {OUT.name}')
