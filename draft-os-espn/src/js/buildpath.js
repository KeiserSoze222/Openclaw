// A3 Build-path guard: can the target build still fit in my remaining picks?
(function () {
  const NS = globalThis.DraftOS;
  const BP = NS.buildpath = {};

  const RELAX = [
    { key: 'QB', floor: 2, label: '3rd QB' },
    { key: 'TE', floor: 1, label: '2nd TE' },
    { key: 'WR', floor: 5, label: '6th WR' },
    { key: 'RB', floor: 5, label: '6th RB' }
  ];

  BP.needed = function (targets, counts) {
    let n = 0;
    for (const pos of Object.keys(targets)) n += Math.max(0, targets[pos] - (counts[pos] || 0));
    return n;
  };

  // -> {counts, picksLeft, targets, needed, reachable, dropped[], remainingText, message}
  BP.guard = function (state) {
    const counts = NS.board.posCounts(NS.board.myRoster(state));
    const cur = NS.board.currentPick(state) || (NS.board.totalPicks(state) + 1);
    const picksLeft = NS.pickorder.myPicks(state.settings).live.filter(p => p >= cur).length;
    const targets = { ...(state.settings.targets || { QB: 2, RB: 5, WR: 5, TE: 1, K: 1, DST: 1 }) };

    const dropped = [];
    let needed = BP.needed(targets, counts);
    while (needed > picksLeft) {
      const relax = RELAX.find(r => targets[r.key] > r.floor);
      if (!relax) break;
      targets[relax.key] -= 1;
      dropped.push(relax.label);
      needed = BP.needed(targets, counts);
    }
    const reachable = needed <= picksLeft;

    const parts = [];
    for (const pos of ['QB', 'RB', 'WR', 'TE', 'K', 'DST']) {
      const rem = Math.max(0, targets[pos] - (counts[pos] || 0));
      if (rem > 0) parts.push(rem > 1 ? `${rem} ${pos}` : pos);
    }
    return {
      counts, picksLeft, targets, needed, reachable, dropped,
      remainingText: `Remaining: ${parts.join(', ') || 'build complete'} in ${picksLeft} picks`,
      message: dropped.length
        ? `Build unreachable - drop ${dropped.join(', then ')}`
        : (reachable ? null : 'Build unreachable even after relaxing all optional targets')
    };
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
