// Shared helpers for every page: Supabase client, player identity, live refresh, photos.
(function () {
  const cfg = window.WR_CONFIG || {};
  const configured = !!(cfg.url && cfg.anonKey && !/YOUR-/.test(cfg.url + cfg.anonKey));
  const sb = configured && window.supabase ? window.supabase.createClient(cfg.url, cfg.anonKey) : null;

  const $ = (s, r = document) => r.querySelector(s);
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F'];
  const teamClass = (id) => 'tc' + (((Number(id) || 1) - 1) % 3 + 1);

  function getMe() {
    try { return JSON.parse(localStorage.getItem('wr-me') || 'null'); } catch (e) { return null; }
  }
  function setMe(v) {
    try { v ? localStorage.setItem('wr-me', JSON.stringify(v)) : localStorage.removeItem('wr-me'); } catch (e) {}
  }

  function friendly(err) {
    const m = (err && (err.message || err.error_description)) || '';
    if (/Failed to fetch|NetworkError|network/i.test(m)) return 'No connection. Check your signal and try again.';
    return m || 'Something went wrong. Try again.';
  }
  async function rpc(fn, args) {
    const { data, error } = await sb.rpc(fn, args || {});
    if (error) throw new Error(friendly(error));
    return data;
  }
  async function rows(table, build) {
    let q = sb.from(table).select('*');
    if (build) q = build(q);
    const { data, error } = await q;
    if (error) throw new Error(friendly(error));
    return data || [];
  }

  // Calls `refresh` now, on every change to the listed tables, and every `pollMs` as a fallback.
  function live(tables, refresh, pollMs) {
    let timer = null, busy = false, again = false;
    const run = async () => {
      if (busy) { again = true; return; }
      busy = true;
      try { await refresh(); } catch (e) { console.warn(e); }
      busy = false;
      if (again) { again = false; run(); }
    };
    const soon = () => { clearTimeout(timer); timer = setTimeout(run, 200); };
    const ch = sb.channel('wr-' + Math.random().toString(36).slice(2));
    tables.forEach((t) => ch.on('postgres_changes', { event: '*', schema: 'public', table: t }, soon));
    ch.subscribe();
    if (pollMs) setInterval(run, pollMs);
    document.addEventListener('visibilitychange', () => { if (!document.hidden) run(); });
    run();
    return run;
  }

  let clockOffset = 0;
  async function syncClock() {
    try {
      const t0 = Date.now();
      const server = await rpc('server_time');
      const t1 = Date.now();
      clockOffset = Number(server) - (t0 + t1) / 2;
    } catch (e) {}
  }
  const now = () => Date.now() + clockOffset;

  function toast(msg, ms = 2600) {
    let el = document.getElementById('wr-toast');
    if (!el) { el = document.createElement('div'); el.id = 'wr-toast'; el.className = 'toast'; el.setAttribute('role', 'status'); document.body.appendChild(el); }
    el.textContent = msg; el.hidden = false;
    clearTimeout(el._t); el._t = setTimeout(() => { el.hidden = true; }, ms);
  }

  // Shrinks a phone photo to at most 1280 px before upload.
  function compress(file, max = 1280, quality = 0.8) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      const url = URL.createObjectURL(file);
      img.onload = () => {
        const scale = Math.min(1, max / Math.max(img.width, img.height));
        const c = document.createElement('canvas');
        c.width = Math.round(img.width * scale); c.height = Math.round(img.height * scale);
        c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
        URL.revokeObjectURL(url);
        c.toBlob((b) => (b ? resolve(b) : reject(new Error('Could not read this photo'))), 'image/jpeg', quality);
      };
      img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('Could not read this photo')); };
      img.src = url;
    });
  }
  async function uploadPhoto(file, folder) {
    const blob = await compress(file);
    const id = (crypto.randomUUID && crypto.randomUUID()) || (Date.now() + '-' + Math.random().toString(36).slice(2));
    const path = `${folder || 'misc'}/${new Date().toISOString().slice(0, 10)}/${id}.jpg`;
    const { error } = await sb.storage.from('photos').upload(path, blob, { contentType: 'image/jpeg', upsert: false });
    if (error) throw new Error(friendly(error));
    return sb.storage.from('photos').getPublicUrl(path).data.publicUrl;
  }

  // Checks the saved player still exists (the host may have reset players).
  async function checkMe() {
    const me = getMe();
    if (!me) return null;
    const r = await rows('participants', (q) => q.eq('id', me.id));
    if (!r.length) { setMe(null); return null; }
    me.team_id = r[0].team_id; me.name = r[0].name; setMe(me);
    return me;
  }

  // Renders the join form into `el`; calls onJoined(me) when done.
  // No join form: people join only by scanning their name badge (card.html checks them in).
  async function renderJoin(el) {
    try { const [st] = await rows('state'); if (isLive(st, 'closed')) { thanks(el); return; } } catch (e) {}
    el.innerHTML = `<section class="card" style="text-align:center;margin-top:12vh"><div class="eyebrow">${esc(cfg.eventName || 'WASH Retreat')}</div><div class="big-msg">Scan your badge</div><p style="margin:0">To join, scan the QR code on your name badge with your phone camera.</p><p class="muted small" style="margin:0">No badge? Ask the facilitator.</p></section>`;
  }
  async function renderJoinForm(el, onJoined) {
    let teams = [];
    try { teams = await rows('teams', (q) => q.order('id')); } catch (e) {}
    let pick = null;
    el.innerHTML = `
      <section class="card">
        <div class="eyebrow">${esc(cfg.eventName || 'WASH Retreat')}</div>
        <h1 style="font-size:30px">Join the game</h1>
        <form id="join-form" class="stack" novalidate>
          <label class="field" for="join-name">Your name<input id="join-name" maxlength="40" autocomplete="name" placeholder="First name and last name" required></label>
          <div class="stack"><span class="small muted" style="font-weight:600">Your team</span>
            <div class="team-pick" id="join-teams">${teams.map((t) => `<button type="button" class="${teamClass(t.id)}" data-team="${t.id}" aria-pressed="false">${esc(t.name)}</button>`).join('')}</div>
            <span class="small muted">Not sure? Leave it and we'll place you.</span>
          </div>
          <p id="join-err" class="notice bad" hidden></p>
          <button class="btn primary block" type="submit">Join</button>
        </form>
      </section>`;
    el.querySelectorAll('[data-team]').forEach((b) => b.addEventListener('click', () => {
      pick = pick === Number(b.dataset.team) ? null : Number(b.dataset.team);
      el.querySelectorAll('[data-team]').forEach((x) => x.setAttribute('aria-pressed', String(Number(x.dataset.team) === pick)));
    }));
    el.querySelector('#join-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const err = el.querySelector('#join-err'); err.hidden = true;
      const name = el.querySelector('#join-name').value.trim();
      if (!name) { err.textContent = 'Please type your name.'; err.hidden = false; return; }
      const btn = e.submitter || el.querySelector('button[type=submit]'); btn.disabled = true;
      try {
        const me = await rpc('join_retreat', { p_name: name, p_team: pick });
        setMe(me); onJoined(me);
      } catch (ex) { err.textContent = ex.message; err.hidden = false; btn.disabled = false; }
    });
  }

  function setupNotice(el) {
    el.innerHTML = `<section class="card"><h1 style="font-size:26px">Setup needed</h1><p>Add the Supabase project URL and anon key in <code>config.js</code>, then reload this page.</p></section>`;
  }

  // The presentation: one ordered list of steps, like slides. Arrow keys move along it.
  // Join screen → each question (a quiz adds "reveal" and "top players") → team scores → podium.
  const shuffle = (arr) => { const a = arr.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  const flow = {
    build(acts) {
      const s = [{ k: 'lobby' }];
      const addQ = (a) => {
        s.push({ k: 'q', a });
        if (a.kind === 'quiz') { s.push({ k: 'reveal', a }); s.push({ k: 'lb', a }); }
        if (a.kind === 'team') { s.push({ k: 'wheel', a }); [0, 1, 2].forEach((i) => s.push({ k: 'tp', a, i })); }
      };
      const S = window.WR_SESSIONS || [];
      const used = new Set(); const open = [];
      S.forEach((ses) => {
        (ses.opens || []).forEach((g) => { if (!open.includes(g)) open.push(g); });
        (ses.closes || []).forEach((g) => { const i = open.indexOf(g); if (i >= 0) open.splice(i, 1); });
        const lv = open.slice();
        s.push({ k: 'session', s: ses, live: lv });
        if (ses.demo) for (let i = 0; i < 7; i++) s.push({ k: 'demo', s: ses, live: lv, i });
        if (ses.screen === 'hunt') { s.push({ k: 'hunt', s: ses, live: lv }); s.push({ k: 'raceres', s: ses, live: lv }); }
        acts.filter((a) => a.position >= ses.from && a.position <= ses.to).forEach((a) => { used.add(a.id); addQ(a); });
        if (ses.key === 'd1-close') { s.push({ k: 'teams' }); [1, 2, 3].forEach((n) => s.push({ k: 'podium', n })); }
      });
      acts.filter((a) => !used.has(a.id)).forEach(addQ);
      s.push({ k: 'end' });
      return s;
    },
    indexOf(steps, st) {
      if (!st) return 0;
      const pr = st.present || null;
      const i = steps.findIndex((x) => {
        if (x.k === 'lobby') return st.screen === 'lobby';
        if (x.k === 'end') return st.screen === 'session' && st.session_key === 'end';
        if (x.k === 'session') return st.screen === 'session' && st.session_key === x.s.key && !(pr && pr.demo != null);
        if (x.k === 'demo') return st.screen === 'session' && st.session_key === x.s.key && !!pr && pr.demo === x.i;
        if (x.k === 'hunt') return st.screen === 'hunt' && st.session_key === x.s.key && !(pr && pr.race);
        if (x.k === 'raceres') return st.screen === 'hunt' && st.session_key === x.s.key && !!(pr && pr.race);
        if (x.k === 'q') return st.screen === 'activity' && st.activity_id === x.a.id && st.phase !== 'reveal' && !(pr && pr.act === x.a.id);
        if (x.k === 'wheel') return st.screen === 'activity' && pr && pr.act === x.a.id && pr.i === -1;
        if (x.k === 'tp') return st.screen === 'activity' && pr && pr.act === x.a.id && pr.i === x.i;
        if (x.k === 'reveal') return st.screen === 'activity' && st.activity_id === x.a.id && st.phase === 'reveal';
        if (x.k === 'lb') return st.screen === 'leaderboard' && st.activity_id === x.a.id;
        if (x.k === 'teams') return st.screen === 'teams';
        if (x.k === 'podium') return st.screen === 'podium' && Math.max(1, st.podium_step || 0) === x.n;
        return false;
      });
      if (i >= 0) return i;
      if (st.screen === 'leaderboard' || st.screen === 'hunt') {
        const j = steps.findIndex((x) => x.a && x.a.id === st.activity_id);
        return j >= 0 ? j : 0;
      }
      return 0;
    },
    // st = the current state, so the presenting order chosen by the wheel stays the same.
    patch(x, st) {
      const pr = st && st.present;
      if (x.k === 'lobby') return { screen: 'lobby', live: ['register'] };
      if (x.k === 'end') return { screen: 'session', session: 'end', live: ['closed'] };
      if (x.k === 'session') return { screen: 'session', session: x.s.key, live: x.live, present: null };
      if (x.k === 'demo') return { screen: 'session', session: x.s.key, live: x.live, present: { demo: x.i } };
      if (x.k === 'hunt') return { screen: 'hunt', session: x.s.key, live: x.live, present: null };
      if (x.k === 'raceres') return { screen: 'hunt', session: x.s.key, live: x.live, present: { race: 'reveal' } };
      if (x.k === 'q') return { activity_id: x.a.id, screen: 'activity', phase: 'open', present: null };
      if (x.k === 'wheel') return { activity_id: x.a.id, screen: 'activity', phase: 'closed', present: { act: x.a.id, order: shuffle([1, 2, 3]), i: -1, at: Date.now() } };
      if (x.k === 'tp') return { activity_id: x.a.id, screen: 'activity', phase: 'closed', present: { act: x.a.id, order: pr && pr.act === x.a.id ? pr.order : shuffle([1, 2, 3]), i: x.i } };
      if (x.k === 'reveal') return { activity_id: x.a.id, screen: 'activity', phase: 'reveal' };
      if (x.k === 'lb') return { screen: 'leaderboard' };
      if (x.k === 'teams') return { screen: 'teams' };
      return { screen: 'podium', podium_step: x.n };
    },
    label(x) {
      if (!x) return 'End';
      if (x.k === 'lobby') return 'Join screen';
      if (x.k === 'end') return 'Close the retreat (all QR codes say thank you)';
      if (x.k === 'session') return x.s.label + ': ' + x.s.title + (x.s.sub ? ' (' + x.s.sub + ')' : '');
      if (x.k === 'demo') return 'Demo step ' + (x.i + 1) + ' of 7';
      if (x.k === 'hunt') return 'Word race on the screen';
      if (x.k === 'raceres') return 'Word race result: the message and the points';
      if (x.k === 'q') return '#' + x.a.position + ' ' + x.a.title;
      if (x.k === 'wheel') return 'Spin the wheel: who presents first';
      if (x.k === 'tp') return 'Presentation ' + (x.i + 1) + ' of 3';
      if (x.k === 'reveal') return 'Reveal the answer';
      if (x.k === 'lb') return 'Top players';
      if (x.k === 'teams') return 'Team scores';
      return ['', 'Podium: 3rd place', 'Podium: 2nd place', 'Podium: the winner'][x.n];
    }
  };
  // Going back from a reveal must not reopen the quiz: show the question closed instead.
  flow.patchBack = (x, st) => (x.k === 'q' && x.a.kind === 'quiz' ? { activity_id: x.a.id, screen: 'activity', phase: 'closed', present: null } : flow.patch(x, st));

  function getPin() { try { return localStorage.getItem('wr-pin') || ''; } catch (e) { return ''; } }
  function setPin(v) { try { v ? localStorage.setItem('wr-pin', v) : localStorage.removeItem('wr-pin'); } catch (e) {} }

  // QR groups: closed until the presenter reaches the session that opens them.
  const GROUPS = { register: 'Registration (join without a badge)', badges: 'Badge questions (letters)', rooms: 'Room card questions (letters)', race: 'Word race board', practice: 'Practice tent (briefing)', lake: 'Helper cards (scan to see what it is)', sap: 'Site test (site and tent forms)', feedback: 'Feedback form', closed: 'Retreat closed: every QR code says thank you' };
  const isLive = (st, g) => !!(st && Array.isArray(st.live) && st.live.includes(g));
  // After the retreat: every page shows only a thank-you.
  function thanks(el) { el.innerHTML = '<section class="card" style="text-align:center;margin-top:20vh"><div class="eyebrow">Where the Waters Meet</div><div class="big-msg">Thank you for joining!</div><p class="muted" style="margin:0">The WASH Sector Coordination Team Retreat is closed. See you at the next one.</p></section>'; }
  async function closedGuard(el) { try { const [s] = await rows('state'); if (isLive(s, 'closed')) { thanks(el); return true; } } catch (e) {} return false; }
  window.WR = { thanks, closedGuard, GROUPS, isLive, flow, getPin, setPin, cfg, configured, sb, $, esc, LETTERS, teamClass, getMe, setMe, rpc, rows, live, syncClock, now, toast, uploadPhoto, checkMe, renderJoin, setupNotice, friendly };
})();
