// Board tracker for the ESPN 12-team 1QB room. Pure functions.
(function () {
  const NS = globalThis.DraftOS;
  const B = NS.board = {};

  B.myTeamName = function (settings) {
    const t = settings.teams.find(t => t.slot === settings.mySlot);
    return t ? t.name : 'Jeff';
  };

  B.myTeamLabel = function (settings) {
    return `${settings.myLabel || 'KeiserSoze'} (${B.myTeamName(settings)})`;
  };

  // Active (round-filled, name-matched) keepers as board entries, with
  // pos/bye resolved from the queue when the player is in it. These are
  // pre-filled into state.picks so the clock skips them and board counts
  // include them from pick 1.
  B.keeperPickEntries = function (state) {
    const settings = state.settings;
    const me = B.myTeamName(settings);
    return NS.pickorder.resolveKeepers(settings).resolved.map(k => {
      const key = NS.normName(k.player);
      const q = (state.myQueue || []).find(p => p.normName === key);
      return {
        pick: k.pick, team: k.team, player: k.player,
        pos: q ? q.pos : '', normName: key, keeper: true,
        byMe: k.team === me
      };
    }).sort((a, b) => a.pick - b.pick);
  };

  B.unmatchedKeepers = function (settings) {
    return NS.pickorder.resolveKeepers(settings).unmatched;
  };

  // normNames of players currently locked up as keepers (active rows only -
  // blanking a round instantly puts the player back in available).
  B.activeKeeperKeys = function (settings) {
    return new Set(NS.pickorder.resolveKeepers(settings).resolved
      .map(k => NS.normName(k.player)));
  };

  B.totalPicks = s => s.settings.teams.length * s.settings.rounds;

  B.currentPick = function (state) {
    const filled = new Set(state.picks.map(p => p.pick));
    const total = B.totalPicks(state);
    for (let p = 1; p <= total; p++) if (!filled.has(p)) return p;
    return null;
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
    B.activeKeeperKeys(state.settings).forEach(k => keys.add(k));
    return keys;
  };

  // Remaining players in my queue order. Active keepers can never appear;
  // a keeper row edited back to blank returns the player instantly.
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

  B.teamCounts = function (state) {
    const out = {};
    state.settings.teams.forEach(t => { out[t.name] = { QB: 0, RB: 0, WR: 0, TE: 0, K: 0, DST: 0 }; });
    state.picks.forEach(p => {
      if (out[p.team] && out[p.team][p.pos] !== undefined) out[p.team][p.pos]++;
    });
    return out;
  };

  // Catch-up paste: walk the pick order from the current pick, skipping
  // already-filled (keeper) picks.
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
        continue;
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
  B.runDetection = function (state) {
    const alerts = [];
    const live = state.picks.filter(p => !p.keeper).sort((a, b) => a.pick - b.pick);
    const counts = B.posCounts(live.slice(-5));
    for (const pos of ['QB', 'RB', 'WR', 'TE']) {
      if (counts[pos] >= 3) alerts.push(`${pos} run in progress (${counts[pos]} of last 5 picks)`);
    }
    const queueTEs = state.myQueue.filter(p => p.pos === 'TE').sort((a, b) => a.rank - b.rank);
    const gone = B.pickedKeys(state);
    const top2Gone = queueTEs.slice(0, 2).length === 2 &&
      queueTEs.slice(0, 2).every(t => gone.has(t.normName));
    const zeroTE = Object.values(B.teamCounts(state)).filter(c => c.TE === 0).length;
    if (top2Gone && zeroTE >= 6) alerts.push(`TE will run (top-2 TEs gone, ${zeroTE} teams with 0 TE)`);
    return alerts;
  };

  // Opponent-need model for a 12-team 1QB room (rule 9 defaults, editable):
  // first QB between rounds 4 and 9, second QB after round 10.
  B.needWeights = function (counts, round, settings) {
    const w = { QB: 0, RB: 0, WR: 0, TE: 0, K: 0, DST: 0 };
    const qd = (settings && settings.simQB) || { firstQBStart: 4, firstQBEnd: 9, secondQBAfter: 10 };
    if (counts.QB === 0) {
      if (round < qd.firstQBStart) w.QB = 0.15;
      else if (round <= qd.firstQBEnd) w.QB = 1.1;
      else w.QB = 1.8; // very late with no QB: urgent
    } else if (counts.QB === 1) {
      w.QB = round > qd.secondQBAfter ? 0.5 : 0.05;
    } else {
      w.QB = 0.02;
    }
    w.RB = Math.max(0.25, 1.5 - counts.RB * 0.25);
    w.WR = Math.max(0.25, 1.5 - counts.WR * 0.25);
    w.TE = counts.TE === 0 ? (round >= 3 ? 0.6 : 0.3) : (counts.TE === 1 ? 0.08 : 0.02);
    const lastRounds = settings ? settings.rounds : 16;
    if (round >= lastRounds - 1) { w.K = counts.K === 0 ? 0.9 : 0; w.DST = counts.DST === 0 ? 0.9 : 0; }
    else if (round >= lastRounds - 3) { w.K = counts.K === 0 ? 0.12 : 0; w.DST = counts.DST === 0 ? 0.12 : 0; }
    return w;
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
