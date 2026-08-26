// Pure snake-draft pick-order engine with keepers pre-filled.
(function () {
  const NS = globalThis.DraftOS;
  const PO = NS.pickorder = {};

  // odd round: (r-1)*10 + slot ; even round: (r-1)*10 + 11 - slot
  PO.pickForSlotRound = function (slot, round, teamCount) {
    const n = teamCount || 10;
    return round % 2 === 1
      ? (round - 1) * n + slot
      : (round - 1) * n + (n + 1) - slot;
  };

  PO.slotForPick = function (pick, teamCount) {
    const n = teamCount || 10;
    const round = Math.ceil(pick / n);
    const idx = pick - (round - 1) * n; // 1..n within the round
    return { round, slot: round % 2 === 1 ? idx : (n + 1) - idx };
  };

  // -> array of {pick, round, slot, team, keeper:null|{player,pos,nfl,team}}
  PO.buildOrder = function (settings) {
    const teams = settings.teams;
    const n = teams.length;
    const total = n * settings.rounds;
    const bySlot = {};
    teams.forEach(t => { bySlot[t.slot] = t.name; });
    const keeperByPick = {};
    (settings.keepers || []).forEach(k => { keeperByPick[k.pick] = k; });
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

  // All pick numbers belonging to my slot, split into keeper vs live.
  PO.myPicks = function (settings) {
    const order = PO.buildOrder(settings);
    const mine = order.filter(o => o.slot === settings.mySlot);
    return {
      all: mine.map(o => o.pick),
      live: mine.filter(o => !o.keeper).map(o => o.pick),
      keeper: mine.filter(o => o.keeper).map(o => o.pick)
    };
  };

  // Next live (non-keeper) pick of mine at or after `fromPick`.
  PO.myNextLivePick = function (settings, fromPick) {
    return PO.myPicks(settings).live.find(p => p >= fromPick) || null;
  };

  // Live picks strictly between two pick numbers (exclusive/exclusive),
  // i.e. how many other teams pick before my turn.
  PO.livePicksBetween = function (settings, fromPickExclusive, toPickExclusive) {
    const order = PO.buildOrder(settings);
    return order.filter(o =>
      o.pick > fromPickExclusive && o.pick < toPickExclusive && !o.keeper).length;
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
