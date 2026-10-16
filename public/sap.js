// WASH SAP field test: the household and site forms, the site cards, and the summary maths.
// Option lists must match supabase/make_content.py, which writes the tent cards and their truth.
window.SAP = (function () {
  const YN = ['Yes', 'No'];
  const SRC = ['Public network', 'Protected borehole', 'Unprotected borehole', 'Water trucking (NGO)', 'Water trucking (occupants)', 'Bottled water'];
  const GREY = ['Above ground', 'Irrigation / stormwater channel', 'Uncovered pit', 'Covered pit', 'Cesspit', 'Septic tank', 'Holding tank', 'Public network'];
  const LEVEL = ['None', 'Negligible', 'Noticeable', 'Prevalent'];
  const HH_TANKS = [80, 200, 500, 1000, 2000];
  const SITE_TANKS = [1000, 2000, 5000, 10000];

  const household = [
    { section: 'People in the household' },
    { id: 'members', label: 'How many people live in this household?', type: 'number' },
    { id: 'children', label: 'How many are under 18?', type: 'number' },
    { id: 'adults', label: 'How many are 18 to 59?', type: 'number' },
    { id: 'elderly', label: 'How many are 60 or older?', type: 'number' },
    { id: 'female_headed', label: 'Is the household headed by a woman?', type: 'choice', options: YN },
    { id: 'disability', label: 'How many members have a physical disability?', type: 'number' },
    { section: 'Water (W.1–W.15, at shelter level)' },
    ...HH_TANKS.map((s) => ({ id: 'tank_' + s, label: `How many ${s.toLocaleString('en')} L tanks at this shelter?`, type: 'number', small: true })),
    { id: 'shared_tank', label: 'Is any of these tanks shared with another family?', type: 'choice', options: YN, hint: 'Count a shared tank for one family only, so it is not counted twice.' },
    { id: 'drink_source', label: 'Main source for drinking and cooking', type: 'choice', options: SRC },
    { id: 'domestic_source', label: 'Main source for washing and cleaning', type: 'choice', options: SRC },
    { id: 'pays_water', label: 'Does the household pay for water?', type: 'choice', options: YN },
    { section: 'Sanitation (at shelter level)' },
    { id: 'greywater', label: 'Where does the shelter’s greywater go?', type: 'choice', options: GREY },
    { id: 'latrine_inside', label: 'Is there a latrine inside the shelter?', type: 'choice', options: YN },
    { id: 'latrine_ok', label: 'Is it improved and usable?', type: 'choice', options: YN, showIf: ['latrine_inside', 'Yes'] },
    { id: 'soap', label: 'Is there soap at the handwashing point?', type: 'choice', options: YN }
  ];

  const kap = [
    { id: 'kap_times', label: 'KAP: Do you know the 5 critical times for handwashing? (ask them to list)', type: 'choice', options: ['Named all 5', 'Named 3–4', 'Named 1–2', 'Does not know'] },
    { id: 'kap_tank', label: 'KAP: How often do you clean your water tanks?', type: 'choice', options: ['Every month', 'Every 3 months', 'Less often', 'Never'] },
    { id: 'kap_qty', label: 'KAP: How satisfied are you with the quantity of water?', type: 'choice', options: ['Very satisfied', 'Satisfied', 'Dissatisfied', 'Very dissatisfied'] }
  ];

  const site = [
    { section: 'Site info (with the shawish)' },
    { id: 'status', label: 'L.13 · Is the site currently empty?', type: 'choice', options: ['Active site', 'Empty site', 'Refused to continue'] },
    { id: 'shawish', label: 'L.14 · Shawish full name', type: 'text' },
    { id: 'shelters', label: 'S.12 · Total number of shelters used for living', type: 'number' },
    { id: 'closeness', label: 'S.13 · How close are shelters to each other?', type: 'choice', options: ['Less than 2 meters', '2 to 4 meters', 'More than 4 meters'] },
    { id: 'wash_group', label: 'S.2 · Is there an active community WASH group or person?', type: 'choice', options: YN },
    { id: 'landlord', label: 'S.14 · Relationship with the landlord', type: 'choice', options: ['Good', 'Average', 'Bad'] },
    { id: 'eviction', label: 'S.15 · Eviction notice in the last 3 months?', type: 'choice', options: YN },
    { section: 'Water at site level' },
    ...SITE_TANKS.map((s) => ({ id: 'ctank_' + s, label: `Community ${s.toLocaleString('en')} L tanks`, type: 'number', small: true })),
    { section: 'Sanitation at site level' },
    { id: 'lat_out', label: 'S.12 · Latrines outside shelters', type: 'number' },
    { id: 'lat_out_ok', label: 'S.13 · How many of these are improved and usable?', type: 'number' },
    { id: 'lat_out_disposal', label: 'Where do the outside latrines discharge?', type: 'choice', options: GREY },
    { id: 'desludging', label: 'S.26 · How often do desludging trucks come?', type: 'choice', options: ['Every week or less', 'Every two weeks', 'Every month', 'Every two months', 'Every three months or more', 'Not needed', 'Not available'] },
    { section: 'Solid waste and environment' },
    { id: 'bins', label: 'M.1–M.8 · Number of large bins (all sizes)', type: 'number' },
    { id: 'waste', label: 'M.9 · Is waste collected?', type: 'choice', options: ['Yes – all of it', 'Yes – part of it', 'Nothing is collected'] },
    { id: 'insects', label: 'E.1 · Problem with insects?', type: 'choice', options: LEVEL },
    { id: 'open_def', label: 'E.4 · Observable open defecation?', type: 'choice', options: LEVEL },
    { id: 'floods', label: 'E.7 · Floods last year (times)', type: 'number' }
  ];

  // What the shawish says: printed on each team's site card.
  const siteCards = {
    1: ['Shawish: Abu Khaled (Khaled Al-Hassan). Site active, 10 shelters, about 2 to 4 m apart.', 'A WASH volunteer (Um Ahmad) checks the tanks. Relations with the landlord are average; no eviction notice.', 'Community storage: 2 × 1,000 L and 1 × 5,000 L tanks.', '4 latrines outside the shelters; 3 are improved and usable. They go to a cesspit, desludged every two months.', '2 large bins; part of the waste is collected. Insects noticeable, no open defecation, flooded twice last winter.'],
    2: ['Shawish: Abu Ali (Ali Mahmoud). Site active, 10 shelters, less than 2 m apart.', 'No WASH group. Relations with the landlord are bad; a verbal eviction notice came last month.', 'Community storage: 1 × 10,000 L tank.', '2 latrines outside; 1 improved and usable. Both go to an uncovered pit; desludging is not available.', 'No bins, nothing is collected. Insects prevalent, open defecation noticeable, flooded 3 times last winter.'],
    3: ['Shawish: Um Hussein (Fatima Hussein). Site active, 10 shelters, more than 4 m apart.', 'An active WASH committee. Relations with the landlord are good; no eviction notice.', 'Community storage: 2 × 2,000 L tanks.', '6 latrines outside; all 6 improved and usable, connected to a holding tank emptied every month.', '3 large bins, all waste collected. Insects negligible, no open defecation, no floods last year.']
  };

  const sample = (N) => (N > 0 ? Math.round((1.28 * 1.28 * N) / (1.28 * 1.28 + 4 * 0.1 * 0.1 * (N - 1))) : 0);
  const n = (v) => { const x = Number(v); return Number.isFinite(x) ? x : 0; };

  function summarise(s) {
    const H = s.households || []; const site = s.site || {};
    const N = n(site.shelters) || s.tents;
    const count = (key, val) => H.filter((h) => h[key] === val).length;
    const tally = (key, opts) => opts.map((o) => [o, count(key, o)]).filter((x) => x[1]);
    const hhTanks = HH_TANKS.reduce((t, sz) => t + H.reduce((a, h) => a + n(h['tank_' + sz]), 0), 0);
    const hhVol = HH_TANKS.reduce((t, sz) => t + sz * H.reduce((a, h) => a + n(h['tank_' + sz]), 0), 0);
    const cTanks = SITE_TANKS.reduce((t, sz) => t + n(site['ctank_' + sz]), 0);
    const cVol = SITE_TANKS.reduce((t, sz) => t + sz * n(site['ctank_' + sz]), 0);
    const latIn = count('latrine_inside', 'Yes'); const latInOk = H.filter((h) => h.latrine_inside === 'Yes' && h.latrine_ok === 'Yes').length;
    const byCollector = {}; H.forEach((h) => { byCollector[h.by || '?'] = (byCollector[h.by || '?'] || 0) + 1; });
    const times = H.map((h) => new Date(h.at).getTime()).concat(s.site_at ? [new Date(s.site_at).getTime()] : []);
    const start = s.first_start ? new Date(s.first_start).getTime() : Math.min(...times);
    const minutes = times.length ? Math.max(0, Math.round((Math.max(...times) - start) / 60000)) : 0;
    return {
      N, need: sample(N), done: H.length, tents: s.tents, kap: H.filter((h) => h.kap).length,
      people: H.reduce((a, h) => a + n(h.members), 0), children: H.reduce((a, h) => a + n(h.children), 0),
      elderly: H.reduce((a, h) => a + n(h.elderly), 0), female: count('female_headed', 'Yes'), disability: H.reduce((a, h) => a + n(h.disability), 0),
      hhTanks, cTanks, tanks: hhTanks + cTanks, volume: (hhVol + cVol) / 1000,
      drink: tally('drink_source', SRC), domestic: tally('domestic_source', SRC), pays: count('pays_water', 'Yes'),
      grey: tally('greywater', GREY), latIn, latInOk, latOut: n(site.lat_out), latOutOk: n(site.lat_out_ok),
      soap: count('soap', 'Yes'), siteDone: !!Object.keys(site).length, byCollector, minutes, siteBy: s.site_by
    };
  }

  // The WAP rule behind each household answer, shown when an answer differs from the tent card.
  const tankRule = 'Count every tank at the shelter by size, inside and outside. Jerrycans and anything under 80 L do not count. One barrel = 200 L, so "five barrels" = 1,000 L, and 1 m³ = 1,000 L.';
  const explain = {
    members: 'Count everyone who lives in the household, all ages.',
    children: 'Children are under 18. Someone who is 18 is an adult, not a child.',
    adults: 'Adults here are 18 to 59. An 18-year-old counts; a 60-year-old does not.',
    elderly: 'Elderly means 60 or older. 59 is still an adult.',
    female_headed: 'Female-headed: usually a widow or an unmarried, divorced or separated woman with children.',
    disability: 'Count members with a permanent physical disability that affects mobility and access to WASH facilities.',
    shared_tank: 'If a tank is shared, say Yes, and count it for one family only so it is not counted twice.',
    drink_source: 'Main source means the one that gives the greatest quantity for that use. Bottled water is its own source; a network tap is "Public network".',
    domestic_source: 'A capped borehole with a slab, sealed underground, is protected; an open dug well is unprotected. Trucking paid by an NGO and by occupants are different options.',
    pays_water: 'Yes if the household pays, inside the rent or separately. Buying bottled water counts as paying.',
    greywater: 'Above ground = runs on the soil. Channel = into a ditch. Uncovered pit = open hole. Covered pit = lid but unlined sides. Cesspit = lined sides and cover, open base.',
    latrine_inside: 'Only latrines inside the shelter count here; shared latrines outside go on the site form.',
    latrine_ok: 'Inside shelters, materials are not considered. Usable = it works and is not permanently blocked. Needing maintenance (not rehabilitation) is still improved and usable.',
    soap: 'Yes only if soap is at the handwashing point when you visit.'
  };
  HH_TANKS.forEach((sz) => { explain['tank_' + sz] = tankRule; });
  const label = (id) => { const f = household.find((x) => x.id === id); return f ? f.label : id; };

  return { household, kap, site, siteCards, sample, summarise, HH_TANKS, SITE_TANKS, explain, label };
})();
