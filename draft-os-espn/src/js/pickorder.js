// Pure snake-draft pick-order engine. Keepers are stored by TEAM NAME +
// round and resolved to pick numbers here, against the current draft order.
(function () {
  const NS = globalThis.DraftOS;
  const PO = NS.pickorder = {};

  // odd round: (r-1)*n + slot ; even round: (r-1)*n + (n+1) - slot
  PO.pickForSlotRound = function (slot, round, teamCount) {
    const n = teamCount || 12;
    return round % 2 === 1
      ? (round - 1) * n + slot
      : (round - 1) * n + (n + 1) - slot;
  };

  PO.slotForPick = function (pick, teamCount) {
    const n = teamCount || 12;
    const round = Math.ceil(pick / n);
    const idx = pick - (round - 1) * n;
    return { round, slot: round % 2 === 1 ? idx : (n + 1) - idx };
  };

  // Resolve keeper rows against the draft order. A blank/invalid round means
  // "not kept" (ignored, player stays in the queue). A filled round whose
  // team name matches nothing goes to `unmatched` - shown with a red badge,
  // excluded from the board, never silently dropped.
  // -> {resolved: [{team, player, round, slot, pick}], unmatched: [row]}
  PO.resolveKeepers = function (settings) {
    const slotByName = {};
    settings.teams.forEach(t => { slotByName[t.name] = t.slot; });
    const resolved = [], unmatched = [];
    (settings.keepers || []).forEach(k => {
      const round = parseInt(k.round, 10);
      if (!round || round < 1 || round > settings.rounds) return; // blank = not kept
      const slot = slotByName[k.team];
      if (slot === undefined) { unmatched.push(k); return; }
      resolved.push({
        team: k.team, player: k.player, round, slot,
        pick: PO.pickForSlotRound(slot, round, settings.teams.length)
      });
    });
    return { resolved, unmatched };
  };

  // -> array of {pick, round, slot, team, keeper:null|{player,...}}
  PO.buildOrder = function (settings) {
    const teams = settings.teams;
    const n = teams.length;
    const total = n * settings.rounds;
    const bySlot = {};
    teams.forEach(t => { bySlot[t.slot] = t.name; });
    const keeperByPick = {};
    PO.resolveKeepers(settings).resolved.forEach(k => { keeperByPick[k.pick] = k; });
    const order = [];
    for (let pick = 1; pick <= total; pick++) {
      const { round, slot } = PO.slotForPick(pick, n);
      order.push({
        pick, round, slot, team: bySlot[slot],
        keeper: keeperByPick[pick] || null
      });
    }
    return order;
  };

  // My pick numbers, split into keeper vs live. A keeper of mine consumes
  // that round's pick, dropping my live-pick count by one.
  PO.myPicks = function (settings) {
    const order = PO.buildOrder(settings);
    const mine = order.filter(o => o.slot === settings.mySlot);
    return {
      all: mine.map(o => o.pick),
      live: mine.filter(o => !o.keeper).map(o => o.pick),
      keeper: mine.filter(o => o.keeper).map(o => o.pick)
    };
  };

  PO.myNextLivePick = function (settings, fromPick) {
    return PO.myPicks(settings).live.find(p => p >= fromPick) || null;
  };

  PO.livePicksBetween = function (settings, fromPickExclusive, toPickExclusive) {
    const order = PO.buildOrder(settings);
    return order.filter(o =>
      o.pick > fromPickExclusive && o.pick < toPickExclusive && !o.keeper).length;
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
