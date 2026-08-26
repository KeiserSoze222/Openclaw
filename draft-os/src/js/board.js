// Board tracker: who picked what, what's left, team tendencies. Pure functions.
(function () {
  const NS = globalThis.DraftOS;
  const B = NS.board = {};

  // Keeper picks are pre-filled into state.picks at init, so "current pick"
  // (first unfilled pick number) naturally skips them on the clock.
  B.keeperPickEntries = function (settings) {
    return (settings.keepers || []).map(k => ({
      pick: k.pick, team: k.team, player: k.player, pos: k.pos || '',
      normName: NS.normName(k.player), keeper: true,
      byMe: k.team === B.myTeamName(settings)
    })).sort((a, b) => a.pick - b.pick);
  };

  B.myTeamName = function (settings) {
    const t = settings.teams.find(t => t.slot === settings.mySlot);
    return t ? t.name : 'Jeff K';
  };

  B.totalPicks = s => s.settings.teams.length * s.settings.rounds;

  B.currentPick = function (state) {
    const filled = new Set(state.picks.map(p => p.pick));
    const total = B.totalPicks(state);
    for (let p = 1; p <= total; p++) if (!filled.has(p)) return p;
    return null; // draft over
  };

  B.isMyPick = function (state, pick) {
    const { slot } = NS.pickorder.slotForPick(pick, state.settings.teams.length);
    return slot === state.settings.mySlot;
  };

  B.teamForPick = function (state, pick) {
    const { slot } = NS.pickorder.slotForPick(pick, state.settings.teams.length);
    const t = state.settings.teams.find(t => t.slot === slot);
    return t ? t.name : '?';
  };

  B.pickedKeys = function (state) {
    const keys = new Set(state.picks.map(p => p.normName));
    (state.settings.keepers || []).forEach(k => keys.add(NS.normName(k.player)));
    return keys;
  };

  // Remaining players in my queue order. Keepers can never appear here.
  B.available = function (state) {
    const gone = B.pickedKeys(state);
    return state.myQueue.filter(p => !gone.has(p.normName));
  };

  B.myRoster = function (state) {
    const me = B.myTeamName(state.settings);
    return state.picks.filter(p => p.byMe || p.team === me)
      .sort((a, b) => a.pick - b.pick);
  };

  B.posCounts = function (players) {
    const c = { QB: 0, RB: 0, WR: 0, TE: 0, K: 0, DST: 0, other: 0 };
    players.forEach(p => { (c[p.pos] !== undefined) ? c[p.pos]++ : c.other++; });
    return c;
  };

  // Per-team positional counts. Keepers count from pick 1 (they're locked in).
  B.teamCounts = function (state) {
    const out = {};
    state.settings.teams.forEach(t => { out[t.name] = { QB: 0, RB: 0, WR: 0, TE: 0, K: 0, DST: 0 }; });
    state.picks.forEach(p => {
      if (out[p.team] && out[p.team][p.pos] !== undefined) out[p.team][p.pos]++;
    });
    return out;
  };

  // Catch-up paste: assign names to teams by walking the pick order from the
  // current pick, skipping already-filled (keeper) picks.
  // -> {assignments:[{pick,team,player,pos,normName,byMe}], unmatched:[{name,suggestions}]}
  B.assignCatchup = function (state, names) {
    const total = B.totalPicks(state);
    const filled = new Set(state.picks.map(p => p.pick));
    const avail = B.available(state).slice();
    const me = B.myTeamName(state.settings);
    const assignments = [], unmatched = [];
    let pick = B.currentPick(state);
    for (const raw of names) {
      while (pick !== null && pick <= total && filled.has(pick)) pick++;
      if (pick === null || pick > total) break;
      const m = NS.matchName(raw, avail);
      if (m.kind !== 'exact') {
        unmatched.push({ name: raw, suggestions: (m.suggestions || []).map(s => s.name) });
        continue; // never a silent drop; do not consume the pick
      }
      const team = B.teamForPick(state, pick);
      assignments.push({
        pick, team, player: m.player.name, pos: m.player.pos,
        normName: m.player.normName, keeper: false, byMe: team === me
      });
      avail.splice(avail.indexOf(m.player), 1);
      filled.add(pick);
      pick++;
    }
    return { assignments, unmatched };
  };

  // "RB run in progress" - 3+ of the last 5 live picks share a position.
  // Plus the TE-specific early warning.
  B.runDetection = function (state) {
    const alerts = [];
    const live = state.picks.filter(p => !p.keeper).sort((a, b) => a.pick - b.pick);
    const last5 = live.slice(-5);
    const counts = B.posCounts(last5);
    for (const pos of ['QB', 'RB', 'WR', 'TE']) {
      if (counts[pos] >= 3) alerts.push(`${pos} run in progress (${counts[pos]} of last 5 picks)`);
    }
    // TE will run: top-2 TEs in my queue gone and 6+ teams still have 0 TE
    const queueTEs = state.myQueue.filter(p => p.pos === 'TE').sort((a, b) => a.rank - b.rank);
    const gone = B.pickedKeys(state);
    const top2Gone = queueTEs.slice(0, 2).length === 2 &&
      queueTEs.slice(0, 2).every(t => gone.has(t.normName));
    const tc = B.teamCounts(state);
    const zeroTE = Object.values(tc).filter(c => c.TE === 0).length;
    if (top2Gone && zeroTE >= 6) alerts.push(`TE will run (top-2 TEs gone, ${zeroTE} teams with 0 TE)`);
    return alerts;
  };

  // "N teams could take a QB before pick 34" - teams with 0-1 QBs holding a
  // pick between now and pick 34.
  B.qb2Competition = function (state) {
    const cur = B.currentPick(state);
    if (cur === null || cur > 34) return null;
    const tc = B.teamCounts(state);
    const me = B.myTeamName(state.settings);
    const order = NS.pickorder.buildOrder(state.settings);
    const filled = new Set(state.picks.map(p => p.pick));
    const teams = new Set();
    order.forEach(o => {
      if (o.pick >= cur && o.pick < 34 && !filled.has(o.pick) && o.team !== me) {
        if ((tc[o.team].QB || 0) <= 1) teams.add(o.team);
      }
    });
    return teams.size;
  };

  // Opponent-need model: relative weight that a team takes each position with
  // its next pick. Superflex pushes QB demand up hard while a team is short.
  B.needWeights = function (counts, round, settings) {
    const w = { QB: 0, RB: 0, WR: 0, TE: 0, K: 0, DST: 0 };
    const qd = (settings && settings.simQB) || { firstQBIn4: 0.7, secondQBByR8: 0.5 };
    // QB: superflex demand
    if (counts.QB === 0) w.QB = round <= 4 ? (2.5 * qd.firstQBIn4) : 2.0;
    else if (counts.QB === 1) w.QB = round <= 8 ? (1.2 * qd.secondQBByR8) : 0.8;
    else if (counts.QB === 2) w.QB = 0.15;
    else w.QB = 0.03;
    // RB/WR toward typical builds
    w.RB = Math.max(0.25, 1.4 - counts.RB * 0.25);
    w.WR = Math.max(0.25, 1.4 - counts.WR * 0.22);
    // TE
    w.TE = counts.TE === 0 ? (round >= 3 ? 0.6 : 0.35) : (counts.TE === 1 ? 0.1 : 0.03);
    // K/DST only late
    if (round >= 17) { w.K = counts.K === 0 ? 0.9 : 0; w.DST = counts.DST === 0 ? 0.9 : 0; }
    else if (round >= 15) { w.K = counts.K === 0 ? 0.15 : 0; w.DST = counts.DST === 0 ? 0.15 : 0; }
    return w;
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
