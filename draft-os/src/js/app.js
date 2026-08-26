// UI layer. Everything below touches the DOM; all draft logic lives in the
// pure modules. In Node this file is a no-op so tests can require the bundle.
(function () {
  const NS = globalThis.DraftOS;
  if (typeof document === 'undefined') {
    if (typeof module !== 'undefined' && module.exports) module.exports = NS;
    return;
  }

  let S = null; // live state
  const ui = {
    tab: 'draft', posFilter: 'ALL', search: '',
    clock: { remaining: 90, running: false, timer: null },
    lastRec: null, roadmap: null
  };

  const $ = sel => document.querySelector(sel);
  const esc = s => String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

  function toast(msg) {
    const t = $('#toast');
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toast._t);
    toast._t = setTimeout(() => t.classList.remove('show'), 2200);
  }

  function save() { NS.store.save(S, localStorage); }

  // Wrap every mutating action: snapshot for undo, run, persist, redraw.
  function act(fn) {
    NS.store.snapshot(S);
    fn();
    save();
    render();
  }

  // ---- boot -----------------------------------------------------------------
  function boot() {
    const loaded = NS.store.load(localStorage);
    if (loaded.corrupt) {
      const useAuto = loaded.autosave &&
        confirm('Stored state is corrupt.\n\nOK = restore from last autosave\nCancel = start fresh');
      S = useAuto ? loaded.autosave : loaded.fresh;
      if (!useAuto && loaded.autosave === null) alert('No autosave found - starting fresh.');
    } else {
      S = loaded.state;
    }
    S.undoStack = S.undoStack || [];
    ui.clock.remaining = S.settings.clockSeconds;
    bindHeader();
    render();
    save();
  }

  // ---- header + clock -------------------------------------------------------
  function bindHeader() {
    $('#clockStart').onclick = () => { ui.clock.running = true; ensureTimer(); };
    $('#clockPause').onclick = () => { ui.clock.running = false; };
    $('#clockReset').onclick = () => { ui.clock.remaining = S.settings.clockSeconds; ui.clock.running = false; renderClock(); };
    $('#ghostBtn').onclick = toggleGhost;
    $('#undoBtn').onclick = () => {
      if (NS.store.undo(S)) { save(); render(); toast('Undone'); }
      else toast('Nothing to undo');
    };
  }

  function ensureTimer() {
    if (ui.clock.timer) return;
    ui.clock.timer = setInterval(() => {
      if (ui.clock.running && ui.clock.remaining > 0) {
        ui.clock.remaining--;
        renderClock();
      }
    }, 1000);
  }

  function renderClock() {
    const c = $('#clock');
    const m = Math.floor(ui.clock.remaining / 60), s = ui.clock.remaining % 60;
    c.textContent = `${m}:${String(s).padStart(2, '0')}`;
    c.classList.toggle('low', ui.clock.remaining <= 15);
  }

  function toggleGhost() {
    act(() => {
      S.ghost = !S.ghost;
      S.log.push({ t: 'ghost', msg: S.ghost ? 'GHOST MODE ON - recs frozen' : 'Ghost mode off - recs resumed' });
    });
  }

  function renderHeader() {
    const cur = NS.board.currentPick(S);
    const info = $('#pickInfo');
    if (cur === null) { info.innerHTML = '<b>Draft complete</b>'; return; }
    const { round } = NS.pickorder.slotForPick(cur, S.settings.teams.length);
    const team = NS.board.teamForPick(S, cur);
    const mine = NS.board.isMyPick(S, cur);
    const next = NS.pickorder.myNextLivePick(S.settings, mine ? cur + 1 : cur);
    const between = next ? NS.pickorder.livePicksBetween(S.settings, mine ? cur : cur - 1, next) : 0;
    info.innerHTML =
      `Pick ${cur} &middot; R${round} &middot; ${mine ? '<span style="color:var(--good)">YOU</span>' : esc(team)}` +
      `<span class="sub">${mine ? 'YOU ARE ON THE CLOCK' : `my next: ${next ?? '-'} (${between} picks away)`}</span>`;
    $('#ghostBtn').classList.toggle('on', !!S.ghost);
    renderClock();
  }

  // ---- shared bits ----------------------------------------------------------
  function playerPills(p) {
    let h = '';
    if (p.tier) h += `<span class="pill">T${p.tier}</span>`;
    if (p.bye != null) h += `<span class="pill">bye ${p.bye}</span>`;
    (p.tags || []).forEach(tag => {
      if (tag !== 'filler') h += `<span class="badge">${esc(tag)}</span>`;
    });
    if (p.marker === 'target') h += '<span class="pill star">&#9733; target</span>';
    if (p.marker === 'avoid') h += '<span class="pill fade">avoid</span>';
    if (p.handcuffOf) h += `<span class="pill">cuff: ${esc(p.handcuffOf)}</span>`;
    if (p.injury) h += `<span class="pill inj">${esc(p.injury)}</span>`;
    if (S.settings.flags.byeLoad && p.allenStack) h += '<span class="pill stack">Allen stack</span>';
    (p.props || []).forEach(pr => {
      if (pr.tag) h += `<span class="pill ${pr.tag === 'money edge' ? 'money' : 'fade'}">${esc(pr.tag)}</span>`;
    });
    return h;
  }

  function survPill(row) {
    const cls = row.label === 'likely' ? 'surv-likely' : row.label === 'coin-flip' ? 'surv-coin' : 'surv-gone';
    const pct = row.prob !== null && row.prob !== undefined ? ` ${row.prob}%` : '';
    return `<span class="pill ${cls}" title="${esc(NS.survival.formulaText(S))}">${row.label}${pct}</span>`;
  }

  function decorateLite(p) {
    const inj = (S.injuries || []).find(i => NS.normName(i.name) === p.normName);
    return { ...p, injury: inj ? inj.tag : null, props: (S.props || []).filter(pr => pr.normName === p.normName), allenStack: p.team === 'BUF' && ['WR', 'TE', 'RB'].includes(p.pos) };
  }

  // ---- pick actions ---------------------------------------------------------
  function markPick(player, byMe, teamOverride) {
    if (byMe && S.settings.flags.resilience) {
      if (!confirm(`Confirm YOUR pick: ${player.name} (${player.pos})?`)) return;
    }
    act(() => {
      const pick = NS.board.currentPick(S);
      if (pick === null) return;
      const team = byMe ? NS.board.myTeamName(S.settings) : (teamOverride || NS.board.teamForPick(S, pick));
      S.picks.push({ pick, team, player: player.name, pos: player.pos, normName: player.normName, keeper: false, byMe });
      const rec = ui.lastRec;
      const matched = !!(byMe && rec && rec.primary && rec.primary.player.normName === player.normName);
      S.log.push({
        t: byMe ? 'mypick' : 'pick', pick, team, player: player.name, pos: player.pos,
        matchedPrimary: byMe ? matched : undefined,
        rules: byMe && rec && rec.primary ? rec.primary.why.rules : []
      });
      if (byMe) {
        const plan = NS.nextPlan(S);
        S.log.push({ t: 'plan', msg: plan });
        S.lastPlan = plan;
      }
      ui.clock.remaining = S.settings.clockSeconds;
      ui.clock.running = false;
    });
  }

  function longPressify(elem, player) {
    let timer = null;
    const start = () => { timer = setTimeout(() => { timer = null; showConflict(player); }, 550); };
    const cancel = () => { if (timer) { clearTimeout(timer); timer = null; } };
    elem.addEventListener('touchstart', start, { passive: true });
    elem.addEventListener('mousedown', start);
    ['touchend', 'touchmove', 'mouseup', 'mouseleave'].forEach(ev => elem.addEventListener(ev, cancel));
  }

  function showConflict(player) {
    const res = NS.conflictCheck(S, player);
    alert(res.legal
      ? `${player.name}: ${res.note}`
      : `${player.name} conflicts with the playbook.\n\n${res.note}`);
  }

  // ---- render root ----------------------------------------------------------
  const TABS = [
    ['draft', 'Draft'], ['playbook', 'Playbook'], ['queue', 'Queue'], ['board', 'Board'],
    ['props', 'Props'], ['fp', 'FP'], ['log', 'Log'], ['settings', 'Settings'], ['sim', 'Simulate']
  ];

  function render() {
    renderHeader();
    const bar = $('#tabbar');
    bar.innerHTML = TABS.map(([id, label]) =>
      `<button data-tab="${id}" class="${ui.tab === id ? 'on' : ''}">${label}</button>`).join('');
    bar.querySelectorAll('button').forEach(b => {
      b.onclick = () => { ui.tab = b.dataset.tab; render(); };
    });
    const main = $('#main');
    main.innerHTML = '';
    const renderers = {
      draft: renderDraftTab, playbook: renderPlaybookTab, queue: renderQueueTab,
      board: renderBoardTab, props: renderPropsTab, fp: renderFpTab,
      log: renderLogTab, settings: renderSettingsTab, sim: renderSimTab
    };
    renderers[ui.tab](main);
    if (S.settings.flags.resilience) {
      // A6: precompute the next-pick rec (and warm the MC cache) off the clock
      setTimeout(() => { try { NS.safeRecommend(S); } catch (e) { /* contained */ } }, 30);
    }
  }

  // ---- DRAFT tab ------------------------------------------------------------
  function renderDraftTab(main) {
    const rec = NS.safeRecommend(S);
    ui.lastRec = rec && !rec.engineError ? rec : ui.lastRec;

    // Alerts
    let alerts = '';
    if (rec.engineError) {
      alerts += `<div class="banner red">engine error - see console / Log tab. Raw list + clock still live.</div>`;
      console.error(rec.engineError);
      if (!S.log.some(l => l.t === 'error' && l.msg === rec.engineError)) {
        S.log.push({ t: 'error', msg: rec.engineError });
      }
    }
    if (S.ghost) alerts += `<div class="banner purple">Recs frozen. Yahoo will use the saved pre-draft list.</div>`;
    if (!rec.engineError) {
      if (rec.week7Alert) alerts += `<div class="banner red">${esc(rec.week7Alert)}</div>`;
      (rec.notes || []).forEach(n => { alerts += `<div class="banner amber">${esc(n)}</div>`; });
    }
    if (S.settings.flags.buildGuard) {
      const g = NS.buildpath.guard(S);
      if (g.message) alerts += `<div class="banner red">${esc(g.message)}</div>`;
      alerts += `<div class="banner amber">${esc(g.remainingText)}</div>`;
    }
    if (S.settings.flags.byeLoad) byeLoadAlerts().forEach(a => { alerts += `<div class="banner ${a.red ? 'red' : 'amber'}">${esc(a.msg)}</div>`; });
    main.insertAdjacentHTML('beforeend', alerts);

    renderRecCard(main, rec);
    renderRoster(main);
    renderAvailable(main);
  }

  function renderRecCard(main, rec) {
    const sec = document.createElement('section');
    sec.className = 'card';
    sec.id = 'recCard';
    if (S.ghost) sec.classList.add('frozen');
    if (rec.engineError || rec.draftOver) {
      sec.innerHTML = rec.draftOver ? '<h2>Draft complete</h2>' : '<h2>Recommendation unavailable</h2>';
      main.appendChild(sec);
      return;
    }
    const rulePills = ids => ids.map(id => `<span class="pill rule">${id}</span>`).join('');

    if (!rec.myPick) {
      sec.innerHTML = `<h2>Next up: pick ${rec.nextMyPick ?? '-'} in ${rec.picksUntilMine} picks</h2>` +
        (S.lastPlan ? `<div class="dim">Plan: ${esc(S.lastPlan)}</div>` : '') +
        `<div class="dim">Watch list (your top legal targets):</div>` +
        (rec.watch || []).map(w =>
          `<div class="recRow"><div class="pInfo"><span class="recName">${esc(w.player.name)}</span>
           <span class="pill">${w.player.pos}</span>${playerPills(w.player)} ${survPill(w)}</div></div>`).join('') +
        panelsHtml(rec);
      main.appendChild(sec);
      return;
    }

    const slotRow = (label, item) => item ? `
      <div class="recRow"><div class="recLabel">${label}</div>
        <div class="pInfo">
          <div><span class="recName">${esc(item.player.name)}</span>
            <span class="pill">${item.player.pos}</span><span class="pill">#${item.player.rank}</span>
            ${playerPills(item.player)} ${rulePills(item.why.rules)}</div>
          <div class="recWhy">${esc(item.why.text)}</div>
        </div></div>` : '';

    sec.innerHTML = `<h2>Pick ${rec.pick} - YOUR PICK</h2>` +
      slotRow('Primary', rec.primary) + slotRow('Alt', rec.alt) + slotRow('Panic', rec.panic) +
      (rec.reachOrWait ? `<div class="dim" style="margin-top:6px">${esc(rec.reachOrWait)}</div>` : '') +
      (S.lastPlan ? `<div class="dim" style="margin-top:6px">Plan: ${esc(S.lastPlan)}</div>` : '') +
      (rec.doNotTake.length ? `<details><summary>Do not take (${rec.doNotTake.length})</summary>` +
        rec.doNotTake.map(d => `<div class="dim">${esc(d.player.name)} - <span class="pill rule">${d.ruleId}</span> ${esc(d.reason)}</div>`).join('') + '</details>' : '') +
      panelsHtml(rec);
    main.appendChild(sec);
    if (rec.primary) {
      const takeBtn = document.createElement('button');
      takeBtn.className = 'primaryBtn';
      takeBtn.textContent = `I picked ${rec.primary.player.name}`;
      takeBtn.style.marginTop = '8px';
      takeBtn.onclick = () => markPick(rec.primary.player, true);
      sec.appendChild(takeBtn);
    }
  }

  function panelsHtml(rec) {
    const st = rec.startable;
    let h = `<div class="countChips" style="margin-top:10px">` +
      ['QB', 'RB', 'WR', 'TE'].map(p => `<span class="pill">startable ${p}: ${st[p]}</span>`).join('') + '</div>';
    h += `<div class="countChips">` + rec.scarcity.map(sc =>
      `<span class="pill" style="${sc.cliff ? 'border-color:var(--bad);color:var(--bad)' : ''}">${sc.pos} cliff: ${sc.gap === null ? `only ${sc.thin} left` : sc.gap}</span>`).join('') + '</div>';
    if (rec.survival && rec.survival.length) {
      h += `<details><summary>Survival to pick ${rec.nextMyPick ?? '-'}</summary>` +
        rec.survival.map(sv => `<div>${esc(sv.player.name)} ${survPill(sv)}</div>`).join('') +
        `<div class="dim">${esc(NS.survival.formulaText(S))}${rec.monteCarlo ? ` Monte Carlo: ${rec.monteCarlo.n} sims${rec.monteCarlo.capped ? ' (capped for speed)' : ''}.` : ''}</div></details>`;
    }
    if (rec.costOfWaiting && rec.costOfWaiting.length) {
      h += `<details><summary>Cost of waiting</summary>` +
        rec.costOfWaiting.map(c => `<div class="dim">${esc(c.text)}</div>`).join('') + '</details>';
    }
    return h;
  }

  function byeLoadAlerts() {
    const out = [];
    const roster = NS.board.myRoster(S).map(p => {
      const q = S.myQueue.find(x => x.normName === p.normName);
      const k = S.settings.keepers.find(k => NS.normName(k.player) === p.normName);
      return { ...p, bye: q ? q.bye : (k && k.nfl ? S.settings.byes[k.nfl] : null) };
    }).filter(p => p.bye != null);
    const byBye = {};
    roster.forEach(p => { (byBye[p.bye] = byBye[p.bye] || []).push(p); });
    for (const [bye, players] of Object.entries(byBye)) {
      if (players.length >= 3) out.push({ red: false, msg: `Bye ${bye}: ${players.length} players (${players.map(p => p.player).join(', ')})` });
      const byPos = {};
      players.forEach(p => { (byPos[p.pos] = byPos[p.pos] || []).push(p); });
      for (const [pos, list] of Object.entries(byPos)) {
        if (list.length >= 2) out.push({ red: true, msg: `Bye ${bye}: ${list.length} ${pos}s share it (${list.map(p => p.player).join(', ')})` });
      }
    }
    return out;
  }

  function renderRoster(main) {
    const roster = NS.board.myRoster(S);
    const counts = NS.board.posCounts(roster);
    const targets = S.settings.targets;
    const SLOTS = ['QB', 'WR', 'WR', 'RB', 'RB', 'TE', 'FLEX', 'FLEX', 'SFLX', 'K', 'DST'];
    const pool = roster.slice();
    const takeWhere = pred => { const i = pool.findIndex(pred); return i >= 0 ? pool.splice(i, 1)[0] : null; };
    const assigned = SLOTS.map(slot => {
      let p = null;
      if (['QB', 'RB', 'WR', 'TE', 'K', 'DST'].includes(slot)) p = takeWhere(x => x.pos === slot);
      else if (slot === 'FLEX') p = takeWhere(x => ['WR', 'RB', 'TE'].includes(x.pos));
      else if (slot === 'SFLX') p = takeWhere(x => ['QB', 'WR', 'RB', 'TE'].includes(x.pos));
      return { slot, p };
    });
    const byeOf = p => {
      const q = S.myQueue.find(x => x.normName === p.normName);
      if (q && q.bye != null) return q.bye;
      const k = S.settings.keepers.find(k => NS.normName(k.player) === p.normName);
      return k && k.nfl ? S.settings.byes[k.nfl] : null;
    };
    const byeCounts = {};
    roster.forEach(p => { const b = byeOf(p); if (b != null) byeCounts[b] = (byeCounts[b] || 0) + 1; });
    const qbW7 = roster.filter(p => p.pos === 'QB' && byeOf(p) === 7);

    const sec = document.createElement('section');
    sec.className = 'card';
    sec.innerHTML = `<h2>My Roster (${roster.length}/19)</h2>` +
      (qbW7.length >= 2 ? `<div class="banner red" style="margin:6px 0">WEEK 7 QB ALERT: ${esc(qbW7.map(p => p.player).join(' + '))} both out</div>` : '') +
      `<div id="rosterGrid">` + assigned.map(a =>
        `<div class="slot">${a.slot}</div><div>${a.p ? `${esc(a.p.player)} <span class="dim">${a.p.pos}${byeOf(a.p) != null ? ' - bye ' + byeOf(a.p) : ''}${a.p.keeper ? ' - keeper' : ''}</span>` : '<span class="dim">-</span>'}</div>`).join('') +
      pool.map(p => `<div class="slot">BN</div><div>${esc(p.player)} <span class="dim">${p.pos}${byeOf(p) != null ? ' - bye ' + byeOf(p) : ''}</span></div>`).join('') +
      `</div><div class="countChips">` +
      ['QB', 'RB', 'WR', 'TE', 'K', 'DST'].map(pos =>
        `<span class="pill" style="${counts[pos] >= targets[pos] ? 'border-color:var(--good)' : ''}">${pos} ${counts[pos]}/${targets[pos]}</span>`).join('') +
      `</div><div class="byeGrid">` +
      Object.keys(byeCounts).sort((a, b) => a - b).map(b =>
        `<span class="byeCell ${b === '7' && qbW7.length >= 2 ? 'hot' : ''}">wk ${b}: ${byeCounts[b]}</span>`).join('') +
      `</div>`;
    main.appendChild(sec);
  }

  function renderAvailable(main) {
    const sec = document.createElement('section');
    sec.className = 'card';
    const avail = NS.board.available(S);
    const cur = NS.board.currentPick(S);
    const filtered = avail.filter(p => {
      if (ui.posFilter !== 'ALL' && p.pos !== ui.posFilter) return false;
      if (ui.search) {
        const m = NS.matchName(ui.search, [p]);
        if (m.kind !== 'exact' && !p.normName.includes(NS.normName(ui.search))) return false;
      }
      return true;
    }).slice(0, 40);

    sec.innerHTML = `<h2>Available (${avail.length})</h2>
      <input id="searchBox" type="search" placeholder="Search players... (type GHOST MODE to freeze)" value="${esc(ui.search)}" style="width:100%">
      <div id="posChips"></div>
      <div class="fieldRow"><label>"Someone else" assigns to:</label><select id="teamSel"></select></div>
      <div id="availList"></div>
      <details><summary>Catch-up paste (last N picks in order)</summary>
        <textarea id="catchupBox" placeholder="Player A, Player B, Player C&#10;(or one per line)"></textarea>
        <button id="catchupApply">Apply catch-up</button>
        <div id="catchupResult" class="dim"></div>
      </details>`;
    main.appendChild(sec);

    const sb = sec.querySelector('#searchBox');
    sb.oninput = () => {
      if (sb.value.trim().toUpperCase() === 'GHOST MODE') { sb.value = ''; ui.search = ''; toggleGhost(); return; }
      ui.search = sb.value;
      renderAvailListOnly(sec, cur);
    };
    const chips = sec.querySelector('#posChips');
    ['ALL', 'QB', 'RB', 'WR', 'TE', 'K', 'DST'].forEach(pos => {
      const b = document.createElement('button');
      b.textContent = pos;
      if (ui.posFilter === pos) b.classList.add('on');
      b.onclick = () => { ui.posFilter = pos; render(); };
      chips.appendChild(b);
    });
    const teamSel = sec.querySelector('#teamSel');
    const onClock = cur !== null ? NS.board.teamForPick(S, cur) : null;
    S.settings.teams.forEach(t => {
      const o = document.createElement('option');
      o.value = t.name; o.textContent = t.name + (t.name === onClock ? ' (on the clock)' : '');
      if (t.name === onClock) o.selected = true;
      teamSel.appendChild(o);
    });
    renderAvailListOnly(sec, cur);

    sec.querySelector('#catchupApply').onclick = () => {
      const names = NS.parser.parseCatchup(sec.querySelector('#catchupBox').value);
      if (!names.length) return;
      const res = NS.board.assignCatchup(S, names);
      act(() => {
        res.assignments.forEach(a => {
          S.picks.push(a);
          S.log.push({ t: a.byMe ? 'mypick' : 'pick', pick: a.pick, team: a.team, player: a.player, pos: a.pos, catchup: true, rules: [] });
        });
      });
      const un = res.unmatched.map(u => `${u.name}${u.suggestions.length ? ` (did you mean: ${u.suggestions.join(' / ')}?)` : ''}`);
      toast(`Assigned ${res.assignments.length} picks${un.length ? `, ${un.length} unmatched` : ''}`);
      if (un.length) alert('Unmatched (fix and re-paste just these):\n' + un.join('\n'));
    };
  }

  function renderAvailListOnly(sec, cur) {
    const nextMine = cur !== null ? NS.pickorder.myNextLivePick(S.settings, NS.board.isMyPick(S, cur) ? cur + 1 : cur) : null;
    const between = nextMine && cur !== null ? NS.pickorder.livePicksBetween(S.settings, NS.board.isMyPick(S, cur) ? cur : cur - 1, nextMine) : 0;
    const avail = NS.board.available(S).filter(p => {
      if (ui.posFilter !== 'ALL' && p.pos !== ui.posFilter) return false;
      if (ui.search && !p.normName.includes(NS.normName(ui.search))) {
        const m = NS.matchName(ui.search, [p]);
        if (m.kind !== 'exact') return false;
      }
      return true;
    }).slice(0, 40);
    const list = sec.querySelector('#availList');
    list.innerHTML = '';
    const teamSel = sec.querySelector('#teamSel');
    avail.forEach(p => {
      const d = decorateLite(p);
      const row = document.createElement('div');
      row.className = 'playerRow';
      const surv = cur !== null ? NS.survival.heuristic(S, p, cur, between) : 'likely';
      row.innerHTML = `<div class="pInfo"><div class="pName">#${p.rank} ${esc(p.name)}</div>
        <div class="pMeta">${p.pos}${p.team ? ' - ' + esc(p.team) : ''}${playerPills(d)} ${survPill({ label: surv, prob: null })}</div></div>`;
      const meBtn = document.createElement('button');
      meBtn.className = 'small primaryBtn';
      meBtn.textContent = 'I picked';
      meBtn.onclick = () => markPick(p, true);
      const otherBtn = document.createElement('button');
      otherBtn.className = 'small';
      otherBtn.textContent = 'Other';
      otherBtn.onclick = () => markPick(p, false, teamSel.value);
      row.appendChild(meBtn);
      row.appendChild(otherBtn);
      longPressify(row.querySelector('.pName'), p);
      list.appendChild(row);
    });
  }

  // ---- PLAYBOOK tab ---------------------------------------------------------
  function renderPlaybookTab(main) {
    main.insertAdjacentHTML('beforeend', `<section class="card"><h2>Playbook (hard rules)</h2>` +
      NS.playbook.RULES.map(r => `<div style="padding:6px 0;border-bottom:1px solid var(--line)">
        <span class="pill rule">${r.ruleId}</span> <b>${esc(r.label)}</b><div class="dim">${esc(r.text)}</div></div>`).join('') +
      `<h3 style="margin-top:12px">Scoring reference</h3><div class="dim">${esc(NS.DATA.SCORING_TEXT)}</div>
      <h3 style="margin-top:12px">Injury / status tags</h3>` +
      S.injuries.map(i => `<div class="dim">${esc(i.name)} - ${esc(i.tag)}</div>`).join('') +
      `</section>`);
  }

  // ---- QUEUE tab ------------------------------------------------------------
  function renderQueueTab(main) {
    const sec = document.createElement('section');
    sec.className = 'card';
    sec.innerHTML = `<h2>My Queue ${S.usingSample ? '<span class="pill" style="border-color:var(--warn);color:var(--warn)">SAMPLE + filler</span>' : ''}</h2>
      <details ${S.usingSample ? 'open' : ''}><summary>Paste rankings (replaces the whole queue)</summary>
        <div class="dim">Formats: "12. Name" / "12 Name RB DET 6" / "12, Name, RB, DET, 6". Lines "---", "===" or "TIER n" are tier breaks.</div>
        <textarea id="queuePaste"></textarea>
        <button class="primaryBtn" id="queueReplace">Replace queue</button>
      </details>
      <details><summary>ADP paste (availability only - never reorders)</summary>
        <textarea id="adpPaste" placeholder="1 Player Name&#10;2 Player Name">${esc((S.adp || []).map(a => `${a.rank} ${a.name}`).join('\n'))}</textarea>
        <button id="adpApply">Save ADP</button> <button id="adpClear">Clear</button>
      </details>
      <div style="margin:8px 0"><button class="small" id="qAdd">+ Add player</button></div>
      <div id="qList"></div>`;
    main.appendChild(sec);

    sec.querySelector('#queueReplace').onclick = () => {
      const text = sec.querySelector('#queuePaste').value;
      if (!text.trim()) return toast('Nothing to paste');
      const parsed = NS.parser.parseQueue(text, { byes: S.settings.byes, keepers: S.settings.keepers, tierSize: S.settings.tierSize });
      if (!parsed.players.length) return toast('No players parsed');
      if (!confirm(`Replace the ENTIRE queue with ${parsed.players.length} players?` +
        (parsed.strippedKeepers.length ? `\n(Keepers stripped: ${parsed.strippedKeepers.join(', ')})` : '') +
        (parsed.warnings.length ? `\n${parsed.warnings.length} unparsed lines will be dropped.` : ''))) return;
      act(() => {
        S.myQueue = parsed.players;
        S.usingSample = false;
        S.log.push({ t: 'queue', msg: `Queue replaced: ${parsed.players.length} players` });
      });
      toast('Queue replaced');
    };
    sec.querySelector('#adpApply').onclick = () => {
      act(() => { S.adp = NS.parser.parseRankList(sec.querySelector('#adpPaste').value, { keepers: S.settings.keepers }); });
      toast(`ADP saved (${S.adp.length})`);
    };
    sec.querySelector('#adpClear').onclick = () => act(() => { S.adp = []; });
    sec.querySelector('#qAdd').onclick = () => {
      const name = prompt('Player name:'); if (!name) return;
      const pos = (prompt('Position (QB/RB/WR/TE/K/DST):') || '').toUpperCase();
      const team = (prompt('NFL team abbrev (blank = unknown):') || '').toUpperCase();
      act(() => {
        S.myQueue.push({
          rank: S.myQueue.length + 1, name, normName: NS.normName(name), pos, team,
          bye: S.settings.byes[team] ?? null, tier: S.myQueue.length ? S.myQueue[S.myQueue.length - 1].tier : 1,
          tags: pos && team ? [] : ['needs data'], marker: null, handcuffOf: null
        });
        renumber();
      });
    };
    renderQueueList(sec.querySelector('#qList'));
  }

  function renumber() {
    S.myQueue.forEach((p, i) => { p.rank = i + 1; });
  }

  function renderQueueList(host) {
    host.innerHTML = '';
    const gone = NS.board.pickedKeys(S);
    let lastTier = null;
    S.myQueue.forEach((p, i) => {
      if (p.tier !== lastTier) {
        lastTier = p.tier;
        const th = document.createElement('div');
        th.className = 'qRow tierHead';
        th.textContent = `TIER ${p.tier}`;
        host.appendChild(th);
      }
      const row = document.createElement('div');
      row.className = 'qRow';
      const drafted = gone.has(p.normName);
      row.innerHTML = `<div class="qName" style="${drafted ? 'text-decoration:line-through;color:var(--dim)' : ''}">
        #${p.rank} ${esc(p.name)} <span class="dim">${p.pos}${p.team ? ' ' + esc(p.team) : ''}${p.bye != null ? ' b' + p.bye : ''}</span>${playerPills(decorateLite(p))}</div>`;
      const mk = (label, fn, cls) => {
        const b = document.createElement('button');
        b.className = 'small' + (cls ? ' ' + cls : '');
        b.innerHTML = label;
        b.onclick = fn;
        return b;
      };
      row.appendChild(mk('&#9650;', () => act(() => { if (i > 0) { S.myQueue.splice(i - 1, 0, S.myQueue.splice(i, 1)[0]); S.myQueue[i - 1].tier = S.myQueue[i].tier; renumber(); } })));
      row.appendChild(mk('&#9660;', () => act(() => { if (i < S.myQueue.length - 1) { S.myQueue.splice(i + 1, 0, S.myQueue.splice(i, 1)[0]); S.myQueue[i + 1].tier = S.myQueue[i].tier; renumber(); } })));
      row.appendChild(mk('&#9998;', () => {
        const name = prompt('Name:', p.name); if (name === null) return;
        const pos = prompt('Pos:', p.pos); if (pos === null) return;
        const team = prompt('Team:', p.team); if (team === null) return;
        act(() => {
          p.name = name; p.normName = NS.normName(name);
          p.pos = pos.toUpperCase(); p.team = team.toUpperCase();
          p.bye = S.settings.byes[p.team] ?? p.bye;
          p.tags = (p.pos && p.team && p.bye != null) ? p.tags.filter(t => t !== 'needs data') : p.tags;
        });
      }));
      if (S.settings.flags.markers) {
        const label = p.marker === 'target' ? '&#9733;' : p.marker === 'avoid' ? '&#10060;' : p.handcuffOf ? '&#128279;' : '&#9734;';
        row.appendChild(mk(label, () => {
          act(() => {
            if (!p.marker && !p.handcuffOf) p.marker = 'target';
            else if (p.marker === 'target') { p.marker = 'avoid'; }
            else if (p.marker === 'avoid') {
              p.marker = null;
              const of = prompt('Handcuff of (blank = none):', '');
              p.handcuffOf = of || null;
            } else { p.handcuffOf = null; p.marker = null; }
          });
        }));
      }
      row.appendChild(mk('&#8213;', () => act(() => { // insert tier break after this player
        for (let j = i + 1; j < S.myQueue.length; j++) S.myQueue[j].tier++;
      })));
      row.appendChild(mk('&#10005;', () => { if (confirm(`Delete ${p.name} from queue?`)) act(() => { S.myQueue.splice(i, 1); renumber(); }); }, 'dangerBtn'));
      longPressify(row.querySelector('.qName'), p);
      host.appendChild(row);
    });
  }

  // ---- BOARD tab ------------------------------------------------------------
  function renderBoardTab(main) {
    const tc = NS.board.teamCounts(S);
    const rows = S.settings.teams.map(t => {
      const c = tc[t.name];
      return `<tr><td>${esc(t.name)}${t.name === NS.board.myTeamName(S.settings) ? ' (you)' : ''}</td>` +
        ['QB', 'RB', 'WR', 'TE', 'K', 'DST'].map(p => `<td>${c[p]}</td>`).join('') + '</tr>';
    }).join('');
    const byTeam = {};
    S.picks.slice().sort((a, b) => a.pick - b.pick).forEach(p => { (byTeam[p.team] = byTeam[p.team] || []).push(p); });
    main.insertAdjacentHTML('beforeend', `<section class="card"><h2>Board</h2>
      <div class="tableWrap"><table><tr><th>Team</th><th>QB</th><th>RB</th><th>WR</th><th>TE</th><th>K</th><th>DST</th></tr>${rows}</table></div>
      <div class="dim" style="margin-top:6px">Counts include keepers from pick 1.</div>` +
      S.settings.teams.map(t => `<details><summary>${esc(t.name)} (${(byTeam[t.name] || []).length})</summary>` +
        (byTeam[t.name] || []).map(p => `<div class="dim">${p.pick}. ${esc(p.player)} (${p.pos})${p.keeper ? ' - keeper' : ''}</div>`).join('') +
        `</details>`).join('') +
      `</section>`);
  }

  // ---- PROPS tab ------------------------------------------------------------
  function renderPropsTab(main) {
    const sec = document.createElement('section');
    sec.className = 'card';
    sec.innerHTML = `<h2>Props / Vegas notes</h2>
      <div class="dim">One per line: PLAYER | PROP TYPE | LINE | NOTE. "over/sharp/volume" tags money edge; "under/fade" tags fade. Annotation only - never reorders anything (R10).</div>
      <textarea id="propsPaste">${esc(S.propsText || '')}</textarea>
      <button class="primaryBtn" id="propsApply">Save props</button>
      <div id="propsList" style="margin-top:8px">` +
      (S.props || []).map(pr => `<div class="dim">${esc(pr.player)} - ${esc(pr.type)} ${esc(pr.line)} ${esc(pr.note)} ${pr.tag ? `<span class="pill ${pr.tag === 'money edge' ? 'money' : 'fade'}">${pr.tag}</span>` : ''}</div>`).join('') +
      `</div>`;
    main.appendChild(sec);
    sec.querySelector('#propsApply').onclick = () => {
      act(() => {
        S.propsText = sec.querySelector('#propsPaste').value;
        S.props = NS.parser.parseProps(S.propsText, { keepers: S.settings.keepers });
      });
      toast(`Saved ${S.props.length} props`);
    };
  }

  // ---- FP tab ---------------------------------------------------------------
  function renderFpTab(main) {
    const sec = document.createElement('section');
    sec.className = 'card';
    let compare = '';
    if ((S.fp || []).length) {
      const cur = NS.board.currentPick(S) || 1;
      const availByKey = {};
      NS.board.available(S).forEach((p, i) => { availByKey[p.normName] = { p, availRank: i + 1 }; });
      const rows = S.fp.map(f => {
        const mine = availByKey[f.normName];
        if (!mine) return `<tr><td>${esc(f.name)}</td><td>${f.rank}</td><td colspan="2" class="dim">not in my available queue</td></tr>`;
        const delta = mine.availRank - f.rank;
        let verdict = 'about even';
        if (delta >= 3) verdict = `FP likes ${esc(f.name)} more than us (+${delta})`;
        else if (delta <= -3) verdict = `We like ${esc(f.name)} more than FP (${delta})`;
        const conflict = NS.conflictCheck(S, mine.p);
        return `<tr><td>${esc(f.name)}</td><td>${f.rank}</td><td>${mine.availRank}</td>
          <td>${verdict}${!conflict.legal ? ` <span class="pill rule">${conflict.ruleId}</span>` : ''}</td></tr>`;
      }).join('');
      compare = `<div class="tableWrap"><table><tr><th>Player</th><th>FP</th><th>My avail rank</th><th>Read</th></tr>${rows}</table></div>`;
    }
    sec.innerHTML = `<h2>FantasyPros compare (second opinion only)</h2>
      <div class="dim">Paste "FP top 20 available" as "rank name" lines. Never auto-picks or reorders.</div>
      <textarea id="fpPaste">${esc(S.fpText || '')}</textarea>
      <button class="primaryBtn" id="fpApply">Save FP list</button>` + compare;
    main.appendChild(sec);
    sec.querySelector('#fpApply').onclick = () => {
      act(() => {
        S.fpText = sec.querySelector('#fpPaste').value;
        S.fp = NS.parser.parseRankList(S.fpText, { keepers: S.settings.keepers });
      });
      render();
    };
  }

  // ---- LOG tab --------------------------------------------------------------
  function buildRecap() {
    const lines = ['=== DRAFT RECAP ==='];
    const picks = S.picks.slice().sort((a, b) => a.pick - b.pick);
    let round = 0;
    picks.forEach(p => {
      const r = NS.pickorder.slotForPick(p.pick, S.settings.teams.length).round;
      if (r !== round) { round = r; lines.push(`\n-- Round ${r} --`); }
      lines.push(`${p.pick}. ${p.team}: ${p.player} (${p.pos})${p.keeper ? ' [keeper]' : ''}${p.byMe ? ' <== ME' : ''}`);
    });
    lines.push('\n=== MY ROSTER ===');
    NS.board.myRoster(S).forEach(p => lines.push(`${p.pick}. ${p.player} (${p.pos})`));
    const counts = NS.board.posCounts(NS.board.myRoster(S));
    lines.push(`Counts: QB ${counts.QB} / RB ${counts.RB} / WR ${counts.WR} / TE ${counts.TE} / K ${counts.K} / DST ${counts.DST}`);
    lines.push('\n=== RULES FIRED PER PICK ===');
    S.log.filter(l => l.t === 'mypick').forEach(l =>
      lines.push(`Pick ${l.pick}: ${l.player} ${l.rules && l.rules.length ? '[' + l.rules.join(', ') + ']' : '[queue order]'}${l.matchedPrimary === false ? ' (off-script)' : ''}`));
    if (S.settings.flags.resilience) {
      const mine = S.log.filter(l => l.t === 'mypick' && l.matchedPrimary !== undefined);
      if (mine.length) {
        const hit = mine.filter(l => l.matchedPrimary).length;
        lines.push(`\n=== DRAFT GRADE ===`);
        lines.push(`Followed primary rec: ${hit}/${mine.length} (${Math.round(100 * hit / mine.length)}%)`);
        if ((S.adp || []).length) {
          let value = 0, n = 0;
          S.log.filter(l => l.t === 'mypick').forEach(l => {
            const a = S.adp.find(x => x.normName === NS.normName(l.player));
            if (a) { value += l.pick - a.rank; n++; }
          });
          if (n) lines.push(`Value vs ADP: ${value >= 0 ? '+' : ''}${value} total picks over ${n} matched picks`);
        }
      }
    }
    return lines.join('\n');
  }

  function renderLogTab(main) {
    const sec = document.createElement('section');
    sec.className = 'card';
    sec.innerHTML = `<h2>Log / Export</h2>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <button id="exportBtn" class="primaryBtn">Export State (JSON)</button>
        <button id="recapBtn">Text recap</button>
      </div>
      <textarea id="ioBox" placeholder="Export appears here. Paste a previous export here and tap Import."></textarea>
      <button id="importBtn" class="dangerBtn">Import State (replaces everything)</button>
      <h3>Draft log</h3><div id="logList">` +
      S.log.slice().reverse().slice(0, 200).map(l => {
        if (l.t === 'plan') return `<div class="dim">&#128203; ${esc(l.msg)}</div>`;
        if (l.t === 'mypick') return `<div><b>Pick ${l.pick}: ${esc(l.player)}</b> ${(l.rules || []).map(r => `<span class="pill rule">${r}</span>`).join('')}${l.matchedPrimary ? ' <span class="pill" style="color:var(--good)">on script</span>' : ''}</div>`;
        if (l.t === 'pick') return `<div class="dim">Pick ${l.pick} - ${esc(l.team)}: ${esc(l.player)} (${esc(l.pos)})</div>`;
        if (l.t === 'error') return `<div class="testFail">ENGINE: ${esc(String(l.msg).slice(0, 200))}</div>`;
        return `<div class="dim">${esc(l.msg || l.t)}</div>`;
      }).join('') + `</div>`;
    main.appendChild(sec);
    sec.querySelector('#exportBtn').onclick = () => {
      const json = JSON.stringify(NS.store.exportable(S), null, 1);
      sec.querySelector('#ioBox').value = json;
      try {
        const blob = new Blob([json], { type: 'application/json' });
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = 'draftos-state.json';
        a.click();
      } catch (e) { /* iOS fallback: copy from the textarea */ }
      toast('Exported - copy the text or save the file');
    };
    sec.querySelector('#recapBtn').onclick = () => { sec.querySelector('#ioBox').value = buildRecap(); };
    sec.querySelector('#importBtn').onclick = () => {
      const raw = sec.querySelector('#ioBox').value.trim();
      if (!raw) return toast('Paste an export first');
      if (!confirm('Import will REPLACE all current state. Continue?')) return;
      try {
        S = NS.store.importJson(raw);
        save();
        render();
        toast('Imported');
      } catch (e) { alert('Import failed: ' + e.message); }
    };
  }

  // ---- SETTINGS tab ---------------------------------------------------------
  function renderSettingsTab(main) {
    const s = S.settings;
    const sec = document.createElement('section');
    sec.className = 'card';
    const num = (id, label, value, step) =>
      `<div class="fieldRow"><label>${label}</label><input type="number" id="${id}" value="${value}" step="${step || 1}"></div>`;
    const flag = (id, label) =>
      `<div class="fieldRow"><label>${label}</label><input type="checkbox" id="${id}" ${s.flags[id.replace('flag_', '')] ? 'checked' : ''}></div>`;
    sec.innerHTML = `<h2>Settings</h2>
      ${num('set_clock', 'Clock seconds', s.clockSeconds)}
      ${num('set_tier', 'Default tier size (no tier breaks pasted)', s.tierSize)}
      ${num('set_scarcity', 'Scarcity cliff gap', s.scarcityGap)}
      ${num('set_panic', 'Panic pick P(available) %', s.panicProb)}
      ${num('set_stQB', 'Startable QB threshold', s.startable.QB)}
      ${num('set_stRB', 'Startable RB threshold', s.startable.RB)}
      ${num('set_stWR', 'Startable WR threshold', s.startable.WR)}
      ${num('set_stTE', 'Startable TE threshold', s.startable.TE)}
      ${num('set_survL', 'Survival "likely" factor', s.survivalFactors.likely, 0.1)}
      ${num('set_survC', 'Survival "coin-flip" factor', s.survivalFactors.coinflip, 0.1)}
      ${num('set_irPick', 'IR stash earliest pick', s.irStashPick)}
      ${num('set_cheapQB', '4th QB earliest pick', s.cheapQBPick)}
      ${num('set_simQ1', 'Sim: P(opponent 1st QB in first 4 rds)', s.simQB.firstQBIn4, 0.05)}
      ${num('set_simQ2', 'Sim: P(opponent 2nd QB by rd 8)', s.simQB.secondQBByR8, 0.05)}
      <div class="fieldRow"><label>QB2 pool (comma-separated)</label></div>
      <textarea id="set_pool">${esc(s.qb2Pool.join(', '))}</textarea>
      <h3>Feature flags (Addendum A - all default OFF)</h3>
      ${flag('flag_monteCarlo', 'A1 Monte Carlo survival')}
      ${flag('flag_roadmap', 'A2 Pre-draft roadmap')}
      ${flag('flag_buildGuard', 'A3 Build-path guard')}
      ${flag('flag_byeLoad', 'A4 Bye-week load + Allen stack')}
      ${flag('flag_markers', 'A5 Queue markers')}
      ${flag('flag_resilience', 'A6 Resilience extras (confirm my pick, precompute, draft grade)')}
      <h3>Draft order (slot: team)</h3><div id="teamEdit"></div>
      <h3>Keepers</h3><div id="keeperEdit"></div>
      <h3>Byes (team week)</h3>
      <textarea id="set_byes">${esc(Object.entries(s.byes).map(([t, b]) => `${t} ${b}`).join('\n'))}</textarea>
      <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:10px">
        <button class="primaryBtn" id="saveSettings">Save settings</button>
        <button id="selfTestBtn">Run self-test</button>
        <button id="roadmapBtn">Generate roadmap</button>
        <button class="dangerBtn" id="resetBtn">Reset app</button>
      </div>
      <div id="selfTestOut" class="mono" style="margin-top:8px;font-size:12px"></div>
      <div id="roadmapOut" style="margin-top:8px"></div>`;
    main.appendChild(sec);

    const teamEdit = sec.querySelector('#teamEdit');
    s.teams.forEach(t => {
      teamEdit.insertAdjacentHTML('beforeend',
        `<div class="fieldRow"><label>Slot ${t.slot}${t.slot === s.mySlot ? ' (you)' : ''}</label>
         <input type="text" data-slot="${t.slot}" value="${esc(t.name)}"></div>`);
    });
    const keeperEdit = sec.querySelector('#keeperEdit');
    s.keepers.forEach((k, i) => {
      keeperEdit.insertAdjacentHTML('beforeend',
        `<div class="fieldRow"><label>${esc(k.team)} R${k.round} (pick ${k.pick})</label>
         <input type="text" data-keeper="${i}" value="${esc(k.player)}" style="width:170px"></div>`);
    });

    sec.querySelector('#saveSettings').onclick = () => {
      act(() => {
        const g = id => sec.querySelector('#' + id);
        s.clockSeconds = +g('set_clock').value || 90;
        s.tierSize = +g('set_tier').value || 12;
        s.scarcityGap = +g('set_scarcity').value || 15;
        s.panicProb = +g('set_panic').value || 80;
        s.startable = { QB: +g('set_stQB').value || 18, RB: +g('set_stRB').value || 30, WR: +g('set_stWR').value || 36, TE: +g('set_stTE').value || 12 };
        s.survivalFactors = { likely: +g('set_survL').value || 1, coinflip: +g('set_survC').value || 0.5 };
        s.irStashPick = +g('set_irPick').value || 147;
        s.cheapQBPick = +g('set_cheapQB').value || 134;
        s.simQB = { firstQBIn4: +g('set_simQ1').value || 0.7, secondQBByR8: +g('set_simQ2').value || 0.5 };
        s.qb2Pool = g('set_pool').value.split(',').map(x => x.trim()).filter(Boolean);
        ['monteCarlo', 'roadmap', 'buildGuard', 'byeLoad', 'markers', 'resilience'].forEach(f => {
          s.flags[f] = g('flag_' + f).checked;
        });
        sec.querySelectorAll('[data-slot]').forEach(inp => {
          const t = s.teams.find(t => t.slot === +inp.dataset.slot);
          if (t && inp.value.trim()) t.name = inp.value.trim();
        });
        sec.querySelectorAll('[data-keeper]').forEach(inp => {
          const k = s.keepers[+inp.dataset.keeper];
          if (k && inp.value.trim()) k.player = inp.value.trim();
        });
        // recompute keeper picks from slot+round in case teams were reordered
        s.keepers.forEach(k => {
          const t = s.teams.find(t => t.name === k.team);
          if (t) k.pick = NS.pickorder.pickForSlotRound(t.slot, k.round, s.teams.length);
        });
        const byes = {};
        sec.querySelector('#set_byes').value.split(/\r?\n/).forEach(line => {
          const m = line.trim().match(/^([A-Za-z]{2,3})\s+(\d+)$/);
          if (m) byes[m[1].toUpperCase()] = +m[2];
        });
        if (Object.keys(byes).length >= 30) s.byes = byes;
        // re-seed keeper board entries in case keepers changed
        const keeperPicks = new Set(s.keepers.map(k => k.pick));
        S.picks = S.picks.filter(p => !p.keeper).concat(NS.board.keeperPickEntries(s))
          .filter((p, i, arr) => arr.findIndex(x => x.pick === p.pick) === i)
          .sort((a, b) => a.pick - b.pick);
        ui.clock.remaining = Math.min(ui.clock.remaining, s.clockSeconds);
      });
      toast('Settings saved');
    };

    sec.querySelector('#selfTestBtn').onclick = () => {
      const out = sec.querySelector('#selfTestOut');
      out.innerHTML = 'running...';
      setTimeout(() => {
        const results = NS.runSelfTests();
        const pass = results.filter(r => r.pass).length;
        out.innerHTML = `<div><b>${pass}/${results.length} passed</b></div>` +
          results.map(r => `<div class="${r.pass ? 'testPass' : 'testFail'}">${r.pass ? 'PASS' : 'FAIL'} ${esc(r.name)}${r.detail ? ' - ' + esc(r.detail) : ''}</div>`).join('');
      }, 30);
    };

    sec.querySelector('#roadmapBtn').onclick = () => {
      if (!s.flags.roadmap) return alert('Enable the A2 roadmap flag first (it runs 100 full mocks - a night-before tool).');
      const out = sec.querySelector('#roadmapOut');
      out.innerHTML = '<div class="dim">Running 100 mocks...</div>';
      setTimeout(() => {
        ui.roadmap = NS.sim.roadmap(S, 100);
        const rows = ui.roadmap.map(r =>
          `<tr><td>${r.pick}</td><td>${esc(r.primary)}</td>
           <td>${r.top3.map(c => `${esc(c.name)} ${c.pct}%`).join('<br>')}</td>
           <td class="mono">${['QB', 'RB', 'WR', 'TE'].map(p => `${p}${r.counts[p]}`).join(' ')}</td></tr>`).join('');
        const text = ui.roadmap.map(r => `Pick ${r.pick}: ${r.primary} | ${r.top3.map(c => `${c.name} ${c.pct}%`).join(', ')} | ` +
          ['QB', 'RB', 'WR', 'TE', 'K', 'DST'].map(p => `${p} ${r.counts[p]}`).join(', ')).join('\n');
        out.innerHTML = `<div class="tableWrap"><table><tr><th>Pick</th><th>Most common</th><th>Top 3</th><th>Counts after</th></tr>${rows}</table></div>
          <details><summary>Export as text</summary><textarea>${esc(text)}</textarea></details>`;
      }, 30);
    };

    sec.querySelector('#resetBtn').onclick = () => {
      if (!confirm('Reset EVERYTHING to defaults? Export first if unsure.')) return;
      if (!confirm('Really reset? This wipes the queue, board and log.')) return;
      S = NS.store.defaultState();
      save();
      render();
    };
  }

  // ---- SIMULATE tab ---------------------------------------------------------
  function renderSimTab(main) {
    const sec = document.createElement('section');
    sec.className = 'card';
    if (!S.sim) S.sim = NS.sim.freshSim(S, { seed: 20260826 });
    const shadow = NS.sim.shadow(S, S.sim);
    const cur = NS.board.currentPick(shadow);
    const myTurn = cur !== null && NS.board.teamForPick(shadow, cur) === NS.board.myTeamName(S.settings);

    sec.innerHTML = `<h2>Mock-draft simulator</h2>
      <div class="dim">Separate from live state. Opponents pick by ${(S.adp || []).length ? 'your pasted ADP' : 'your queue'} + need model + mild randomness.</div>
      <div class="fieldRow"><label>Protect list (sim never takes; comma-separated)</label></div>
      <textarea id="protectBox">${esc((S.sim.protect || []).join(', '))}</textarea>
      <div style="display:flex;gap:8px;flex-wrap:wrap;margin:8px 0">
        <button class="primaryBtn" id="simAuto">Auto-draft to my pick</button>
        <button class="dangerBtn" id="simReset">Reset sim</button>
      </div>
      <div id="simStatus">${cur === null ? '<b>Sim draft complete.</b>' :
        `<b>Sim pick ${cur}</b> - ${myTurn ? '<span style="color:var(--good)">YOUR PICK</span>' : esc(NS.board.teamForPick(shadow, cur))}`}</div>
      <div id="simRec"></div>
      <div id="simAvail"></div>
      <details><summary>Sim log (${S.sim.log.length})</summary>${S.sim.log.slice().reverse().map(l => `<div class="dim">${esc(l)}</div>`).join('')}</details>`;
    main.appendChild(sec);

    const saveProtect = () => {
      S.sim.protect = sec.querySelector('#protectBox').value.split(',').map(x => x.trim()).filter(Boolean);
    };
    sec.querySelector('#protectBox').onchange = () => { saveProtect(); save(); };
    sec.querySelector('#simAuto').onclick = () => {
      saveProtect();
      NS.sim.autoToMyPick(S, S.sim);
      save();
      render();
    };
    sec.querySelector('#simReset').onclick = () => {
      saveProtect();
      S.sim = NS.sim.freshSim(S, { seed: Math.floor(Math.random() * 1e9), protect: S.sim.protect });
      save();
      render();
    };

    if (myTurn) {
      const rec = NS.safeRecommend(shadow);
      const recHost = sec.querySelector('#simRec');
      if (rec.engineError) recHost.innerHTML = '<div class="banner red">engine error in sim - see console</div>';
      else if (rec.primary) {
        recHost.innerHTML = `<div class="recRow"><div class="recLabel">Primary</div><div class="pInfo">
          <div><span class="recName">${esc(rec.primary.player.name)}</span> <span class="pill">${rec.primary.player.pos}</span>
          ${rec.primary.why.rules.map(r => `<span class="pill rule">${r}</span>`).join('')}</div>
          <div class="recWhy">${esc(rec.primary.why.text)}</div></div></div>` +
          (rec.alt ? `<div class="dim">Alt: ${esc(rec.alt.player.name)}</div>` : '');
      }
      const availHost = sec.querySelector('#simAvail');
      NS.board.available(shadow).slice(0, 15).forEach(p => {
        const row = document.createElement('div');
        row.className = 'playerRow';
        row.innerHTML = `<div class="pInfo"><div class="pName">#${p.rank} ${esc(p.name)}</div><div class="pMeta">${p.pos}${p.team ? ' - ' + esc(p.team) : ''}</div></div>`;
        const b = document.createElement('button');
        b.className = 'small primaryBtn';
        b.textContent = 'Draft';
        b.onclick = () => { NS.sim.simMyPick(S, S.sim, p); save(); render(); };
        row.appendChild(b);
        availHost.appendChild(row);
      });
    }
  }

  // go (guard against booting twice)
  let booted = false;
  const bootOnce = () => { if (!booted) { booted = true; boot(); } };
  window.addEventListener('DOMContentLoaded', bootOnce);
  if (document.readyState !== 'loading') bootOnce();
})();
