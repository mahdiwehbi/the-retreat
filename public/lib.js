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
  async function renderJoin(el, onJoined) {
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

  window.WR = { cfg, configured, sb, $, esc, LETTERS, teamClass, getMe, setMe, rpc, rows, live, syncClock, now, toast, uploadPhoto, checkMe, renderJoin, setupNotice, friendly };
})();
