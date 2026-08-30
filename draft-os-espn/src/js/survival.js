// Survival estimates: cheap heuristic by default, Monte Carlo when the A1
// flag is on. Both answer "will this player still be there at my next pick?"
(function () {
  const NS = globalThis.DraftOS;
  const SV = NS.survival = {};

  SV.adpRank = function (state, player) {
    const row = (state.adp || []).find(a => a.normName === player.normName);
    return row ? row.rank : null;
  };

  // Heuristic (the live-clock default):
  //   ref = ADP rank if pasted, else my queue rank
  //   margin = ref - currentPick
  //   margin >= picksBetween * likelyFactor  -> likely
  //   margin >= picksBetween * coinFactor    -> coin-flip
  //   else                                   -> gone
  SV.heuristic = function (state, player, currentPick, picksBetween) {
    const f = state.settings.survivalFactors || { likely: 1.0, coinflip: 0.5 };
    const ref = SV.adpRank(state, player) ?? player.rank;
    const margin = ref - currentPick;
    if (margin >= picksBetween * f.likely) return 'likely';
    if (margin >= picksBetween * f.coinflip) return 'coin-flip';
    return 'gone';
  };

  SV.formulaText = function (state) {
    const f = state.settings.survivalFactors || { likely: 1.0, coinflip: 0.5 };
    return `margin = (ADP rank if pasted, else queue rank) - current pick. ` +
      `likely if margin >= picks-between x ${f.likely}; coin-flip if >= picks-between x ${f.coinflip}; else gone.`;
  };

  // Monte Carlo (A1): N fast sims from the current board to my next pick.
  // Cached by board signature; caps out early if it would blow the 1s budget.
  let mcCache = { sig: null, result: null };

  SV.boardSignature = function (state) {
    return state.picks.map(p => p.pick).join(',') + '|' + (state.adp || []).length +
      '|' + state.myQueue.length;
  };

  SV.monteCarlo = function (state, opts) {
    opts = opts || {};
    const sig = SV.boardSignature(state) + '|' + JSON.stringify(opts.protect || []);
    if (!opts.force && mcCache.sig === sig && mcCache.result) return mcCache.result;

    const N = opts.n || 200;
    const budgetMs = opts.budgetMs || 900;
    const cur = NS.board.currentPick(state);
    const target = opts.targetPick ||
      NS.pickorder.myNextLivePick(state.settings, NS.board.isMyPick(state, cur) ? cur + 1 : cur);
    if (!target) return { probs: {}, n: 0, targetPick: null, capped: false };

    const top = NS.board.available(state).slice(0, 15);
    const counts = {};
    top.forEach(p => { counts[p.normName] = 0; });

    const t0 = Date.now();
    let ran = 0, capped = false;
    const seedBase = opts.seed !== undefined ? opts.seed : 1234567;
    for (let i = 0; i < N; i++) {
      if (Date.now() - t0 > budgetMs) { capped = true; break; }
      const rng = NS.makeRng(seedBase + i * 7919);
      const survivors = NS.sim.simulateToTarget(state, target, rng, { protect: opts.protect });
      top.forEach(p => { if (survivors.has(p.normName)) counts[p.normName]++; });
      ran++;
    }
    const probs = {};
    top.forEach(p => { probs[p.normName] = ran ? Math.round(100 * counts[p.normName] / ran) : 0; });
    const result = { probs, n: ran, targetPick: target, capped, ms: Date.now() - t0 };
    mcCache = { sig, result };
    return result;
  };

  SV.clearCache = function () { mcCache = { sig: null, result: null }; };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
