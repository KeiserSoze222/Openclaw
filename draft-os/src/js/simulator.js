// Mock-draft simulator + fast sims for Monte Carlo. Opponents draft off ADP
// (else my queue) through the opponent-need model with mild randomness.
(function () {
  const NS = globalThis.DraftOS;
  const SIM = NS.sim = {};

  const refRank = (state, p) => NS.survival.adpRank(state, p) ?? p.rank;

  // One opponent pick. availList is queue-ordered; returns chosen player or null.
  SIM.opponentChoose = function (state, availList, picksSoFar, pickNo, team, rng, opts) {
    opts = opts || {};
    const protect = new Set((opts.protect || []).map(NS.normName));
    const { round } = NS.pickorder.slotForPick(pickNo, state.settings.teams.length);

    const counts = { QB: 0, RB: 0, WR: 0, TE: 0, K: 0, DST: 0 };
    picksSoFar.forEach(p => { if (p.team === team && counts[p.pos] !== undefined) counts[p.pos]++; });
    const w = NS.board.needWeights(counts, round, state.settings);

    // Handcuffs go late: not before pick 100 unless the starter just went.
    const recent = picksSoFar.filter(p => p.pick >= pickNo - 2 && p.pick < pickNo);
    const handcuffOk = p => {
      if (!p.handcuffOf) return true;
      if (pickNo >= 100) return true;
      const starterKey = NS.normName(p.handcuffOf);
      // O4: a keeper starter never triggers the last-2-picks unlock
      const starterIsKeeper = (state.settings.keepers || []).some(k => NS.normName(k.player) === starterKey);
      if (starterIsKeeper) return false;
      return recent.some(r => r.normName === starterKey);
    };

    const pool = availList
      .filter(p => !protect.has(p.normName))
      .filter(p => (w[p.pos] || 0) > 0 || !['K', 'DST'].includes(p.pos))
      .filter(handcuffOk)
      .sort((a, b) => refRank(state, a) - refRank(state, b))
      .slice(0, 12);
    if (!pool.length) return availList.find(p => !protect.has(p.normName)) || availList[0] || null;

    let total = 0;
    const weights = pool.map((p, i) => {
      const s = Math.exp(-i / 1.3) * (0.2 + (w[p.pos] || 0));
      total += s;
      return s;
    });
    let r = rng() * total;
    for (let i = 0; i < pool.length; i++) {
      r -= weights[i];
      if (r <= 0) return pool[i];
    }
    return pool[0];
  };

  // Fast sim used by Monte Carlo: from the current board to targetPick
  // (exclusive), opponents only. My unfilled picks in the window are skipped
  // (nobody is removed) - see ASSUMPTIONS.md. Returns surviving normName Set.
  SIM.simulateToTarget = function (state, targetPick, rng, opts) {
    const total = NS.board.totalPicks(state);
    const filled = new Set(state.picks.map(p => p.pick));
    const picksSoFar = state.picks.slice();
    let avail = NS.board.available(state).slice();
    const me = NS.board.myTeamName(state.settings);
    for (let pick = 1; pick < Math.min(targetPick, total + 1); pick++) {
      if (filled.has(pick)) continue;
      const team = NS.board.teamForPick(state, pick);
      if (team === me) continue;
      const chosen = SIM.opponentChoose(state, avail, picksSoFar, pick, team, rng, opts);
      if (chosen) {
        avail = avail.filter(p => p !== chosen);
        picksSoFar.push({ pick, team, player: chosen.name, pos: chosen.pos, normName: chosen.normName });
      }
    }
    return new Set(avail.map(p => p.normName));
  };

  // ---- Simulate tab (separate from live state) ------------------------------

  SIM.freshSim = function (state, opts) {
    return {
      picks: NS.board.keeperPickEntries(state.settings),
      log: [],
      protect: (opts && opts.protect) || (state.sim && state.sim.protect) || [],
      seed: (opts && opts.seed) || Math.floor(1e9 * ((opts && opts.rand) || 0.42)) + 7,
      step: 0
    };
  };

  // A live-shaped view of the sim board so recommend()/board fns work on it.
  SIM.shadow = function (state, sim) {
    return Object.assign({}, state, { picks: sim.picks, ghost: false });
  };

  // Advance the sim until it's my pick (or the draft ends). Mutates sim.
  SIM.autoToMyPick = function (state, sim) {
    const shadow = SIM.shadow(state, sim);
    const me = NS.board.myTeamName(state.settings);
    let guard = 0;
    while (guard++ < 400) {
      const cur = NS.board.currentPick(shadow);
      if (cur === null) return { done: true };
      const team = NS.board.teamForPick(shadow, cur);
      if (team === me) return { done: false, pick: cur };
      const rng = NS.makeRng(sim.seed + sim.step * 104729);
      sim.step++;
      const avail = NS.board.available(shadow);
      const chosen = SIM.opponentChoose(shadow, avail, sim.picks, cur, team, rng, { protect: sim.protect });
      if (!chosen) return { done: true };
      sim.picks.push({ pick: cur, team, player: chosen.name, pos: chosen.pos, normName: chosen.normName, keeper: false, byMe: false });
      sim.log.push(`Pick ${cur} - ${team}: ${chosen.name} (${chosen.pos})`);
    }
    return { done: true };
  };

  SIM.simMyPick = function (state, sim, player) {
    const shadow = SIM.shadow(state, sim);
    const cur = NS.board.currentPick(shadow);
    const me = NS.board.myTeamName(state.settings);
    sim.picks.push({ pick: cur, team: me, player: player.name, pos: player.pos, normName: player.normName, keeper: false, byMe: true });
    sim.log.push(`Pick ${cur} - ${me} (you): ${player.name} (${player.pos})`);
  };

  // ---- Roadmap (A2): full mocks with the engine picking for me --------------

  SIM.fullMock = function (state, seed, opts) {
    const sim = SIM.freshSim(state, { seed, protect: (opts && opts.protect) || [] });
    const me = NS.board.myTeamName(state.settings);
    const myPicksLog = [];
    let guard = 0;
    while (guard++ < 400) {
      const res = SIM.autoToMyPick(state, sim);
      if (res.done) break;
      const shadow = SIM.shadow(state, sim);
      const rec = NS.safeRecommend(shadow);
      const avail = NS.board.available(shadow);
      const choice = (rec && rec.primary && rec.primary.player)
        ? avail.find(p => p.normName === rec.primary.player.normName) || avail[0]
        : avail[0];
      if (!choice) break;
      SIM.simMyPick(state, sim, choice);
      const counts = NS.board.posCounts(NS.board.myRoster(SIM.shadow(state, sim)));
      myPicksLog.push({ pick: res.pick, player: choice.name, pos: choice.pos, counts: { ...counts } });
    }
    return { sim, myPicksLog };
  };

  SIM.roadmap = function (state, runs) {
    runs = runs || 100;
    const perPick = {}; // pick -> {counts: {name: n}, posTotals: {...sum}, runs}
    for (let i = 0; i < runs; i++) {
      const { myPicksLog } = SIM.fullMock(state, 1000 + i * 613, { protect: (state.sim && state.sim.protect) || [] });
      for (const row of myPicksLog) {
        const slot = perPick[row.pick] || (perPick[row.pick] = { names: {}, posSums: { QB: 0, RB: 0, WR: 0, TE: 0, K: 0, DST: 0 }, runs: 0 });
        slot.names[row.player] = (slot.names[row.player] || 0) + 1;
        for (const pos of Object.keys(slot.posSums)) slot.posSums[pos] += row.counts[pos] || 0;
        slot.runs++;
      }
    }
    return Object.keys(perPick).map(Number).sort((a, b) => a - b).map(pick => {
      const slot = perPick[pick];
      const top = Object.entries(slot.names).sort((a, b) => b[1] - a[1]);
      const counts = {};
      for (const pos of Object.keys(slot.posSums)) counts[pos] = Math.round(slot.posSums[pos] / slot.runs);
      return {
        pick,
        primary: top[0] ? top[0][0] : '-',
        top3: top.slice(0, 3).map(([name, n]) => ({ name, pct: Math.round(100 * n / slot.runs) })),
        counts
      };
    });
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
