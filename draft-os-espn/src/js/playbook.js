// ESPN 1QB playbook (rules R1-R10). Every recommendation cites ruleIds.
(function () {
  const NS = globalThis.DraftOS;
  const PB = NS.playbook = {};

  PB.RULES = [
    { ruleId: 'R1', label: 'Rounds 1-4 are skill only', text: 'My picks in rounds 1-4: RB/WR/TE only, no exceptions - not even elite QBs. TE in rounds 1-4 only if the TE is McBride or Bowers.' },
    { ruleId: 'R2', label: 'First QB timing', text: 'First QB no earlier than my 6th live pick. ONE exception: at my 5th live pick only, take Allen, Lamar, or Hurts if he is a full queue tier above the best remaining skill player. Rule 1 always wins in rounds 1-4.' },
    { ruleId: 'R3', label: 'Target build', text: '2 QB (3rd only after overall pick 130), 5-6 RB, 5-6 WR, 1 TE (2nd only if both are top-6 TEs in my queue), 1 K, 1 DST. My keeper counts toward these targets.' },
    { ruleId: 'R4', label: 'K/DST timing', text: 'K and DST only on my last two live picks, whatever those pick numbers are after keepers and round-count settings. Never two of the same.' },
    { ruleId: 'R5', label: 'Five-name card', text: 'Rec card shows FIVE names: Primary + Alt2-Alt5, mixed positions, each with a one-line why and rule ids.' },
    { ruleId: 'R6', label: 'Handcuff timing', text: 'Handcuff-tagged players (user marker only): not recommendable before overall pick 100, or immediately if that starter went in the last 2 picks.' },
    { ruleId: 'R7', label: 'Upside overlay', text: 'Overlay carries over: same tier, within 6 ranks, top-3 legal, strictly below the playbook. A Target later marked as a keeper is stripped with no error.' },
    { ruleId: 'R8', label: 'No QB3 over starters', text: 'Never recommend a 3rd QB over a starting-caliber RB/WR (within the startable thresholds).' },
    { ruleId: 'R9', label: '1QB recalibration', text: 'Startable QB = top 15 (editable). Sim: each opponent takes its first QB between rounds 4 and 9, second QB after round 10 (editable).' },
    { ruleId: 'R10', label: 'Ghost mode', text: 'GHOST MODE banner: "Recs frozen. Use the paper / ESPN queue."' }
  ];

  PB.ruleById = id => PB.RULES.find(r => r.ruleId === id);

  // My K/DST window: my last two live picks under the current settings.
  PB.kdstPicks = function (settings) {
    return NS.pickorder.myPicks(settings).live.slice(-2);
  };

  PB.posRankMap = function (queue) {
    const map = {};
    const byPos = {};
    queue.slice().sort((a, b) => a.rank - b.rank).forEach(p => {
      byPos[p.pos] = (byPos[p.pos] || 0) + 1;
      map[p.normName] = byPos[p.pos];
    });
    return map;
  };

  // Startable = within the per-position threshold, counted within my queue.
  PB.startableRemaining = function (state, available) {
    const th = state.settings.startable; // {QB:15, RB:30, WR:36, TE:12}
    const posRank = PB.posRankMap(state.myQueue);
    const out = { QB: 0, RB: 0, WR: 0, TE: 0 };
    available.forEach(p => {
      if (out[p.pos] !== undefined && posRank[p.normName] <= (th[p.pos] || 999)) out[p.pos]++;
    });
    return out;
  };

  // Rule 2 exception check at my 5th live pick: the best available elite QB
  // (Allen/Lamar/Hurts) that sits a full queue tier above the best remaining
  // skill player. -> {fires, candidate, bestSkillTier}
  PB.rule2Exception = function (state, ctx, available) {
    if (ctx.liveIndex !== 4 || ctx.counts.QB > 0 || ctx.round <= 4) {
      return { fires: false, candidate: null, bestSkillTier: ctx.bestSkillTier };
    }
    const elite = new Set((state.settings.eliteQBs || []).map(NS.normName));
    const candidate = available.find(p =>
      p.pos === 'QB' && elite.has(p.normName) && p.tier < ctx.bestSkillTier);
    return { fires: !!candidate, candidate: candidate || null, bestSkillTier: ctx.bestSkillTier };
  };

  // Legality of one player at one of my picks.
  PB.legality = function (state, ctx, player) {
    const s = state.settings;
    const pick = ctx.pick;
    const counts = ctx.counts;

    // R4 - K/DST only on my last two live picks; never a second
    if (player.pos === 'K' || player.pos === 'DST') {
      if (!ctx.kdst.includes(pick)) {
        return { legal: false, ruleId: 'R4', reason: `K/DST only at my last two live picks (${ctx.kdst.join(' and ')})` };
      }
      if (counts[player.pos] >= 1) {
        return { legal: false, ruleId: 'R4', reason: `never a second ${player.pos}` };
      }
    }

    // R1 - rounds 1-4: RB/WR/TE only; TE only McBride/Bowers. Absolute.
    if (ctx.round <= 4) {
      if (!NS.SKILL.includes(player.pos)) {
        return { legal: false, ruleId: 'R1', reason: 'rounds 1-4 = RB/WR/TE only, no exceptions' };
      }
      if (player.pos === 'TE' && !ctx.earlyTEKeys.has(player.normName)) {
        return { legal: false, ruleId: 'R1', reason: 'rounds 1-4 TE only if McBride or Bowers' };
      }
    }

    if (player.pos === 'QB') {
      // R2 - first QB timing (my 5th live pick = exception window only)
      if (counts.QB === 0) {
        if (ctx.liveIndex < 4) {
          return { legal: false, ruleId: 'R2', reason: 'first QB no earlier than my 6th live pick' };
        }
        if (ctx.liveIndex === 4) {
          const elite = new Set((s.eliteQBs || []).map(NS.normName));
          const ok = ctx.round > 4 && elite.has(player.normName) && player.tier < ctx.bestSkillTier;
          if (!ok) {
            return { legal: false, ruleId: 'R2', reason: '5th-live-pick window: Allen/Lamar/Hurts only, a full tier above the best remaining skill player' };
          }
        }
      }
      // R3 - QB caps: 3rd only after overall pick 130, never a 4th
      if (counts.QB >= 3) return { legal: false, ruleId: 'R3', reason: 'never a 4th QB' };
      if (counts.QB === 2 && pick < s.qb3Pick) {
        return { legal: false, ruleId: 'R3', reason: `3rd QB only after overall pick ${s.qb3Pick}` };
      }
      // R8 - never a 3rd QB over a starting-caliber RB/WR
      if (counts.QB >= 2 && (ctx.startable.RB > 0 || ctx.startable.WR > 0)) {
        return { legal: false, ruleId: 'R8', reason: 'starting-caliber RB/WR still available - no 3rd QB over them' };
      }
    }

    // R3 - TE2 gate: only if both TEs are top-6 in my queue
    if (player.pos === 'TE' && counts.TE >= 1) {
      if (counts.TE >= 2) return { legal: false, ruleId: 'R3', reason: 'never a 3rd TE' };
      const rosterTE = ctx.myTEKeys[0];
      const bothTop6 = ctx.top6TEKeys.has(player.normName) &&
        (rosterTE === undefined || ctx.top6TEKeys.has(rosterTE));
      if (!bothTop6) {
        return { legal: false, ruleId: 'R3', reason: 'TE2 only if both TEs are top-6 in my queue' };
      }
    }

    return { legal: true };
  };

  PB.buildCtx = function (state, pick) {
    const s = state.settings;
    const roster = NS.board.myRoster(state);
    const counts = NS.board.posCounts(roster);
    const queueTEs = state.myQueue.filter(p => p.pos === 'TE').sort((a, b) => a.rank - b.rank);
    const live = NS.pickorder.myPicks(s).live;
    let liveIndex = live.indexOf(pick);
    if (liveIndex < 0) {
      const next = live.findIndex(p => p >= pick);
      liveIndex = next >= 0 ? next : live.length;
    }
    const available = NS.board.available(state);
    const skillTiers = available.filter(p => NS.SKILL.includes(p.pos)).map(p => p.tier);
    return {
      pick,
      round: NS.pickorder.slotForPick(pick, s.teams.length).round,
      counts, liveIndex,
      kdst: PB.kdstPicks(s),
      top6TEKeys: new Set(queueTEs.slice(0, 6).map(t => t.normName)),
      myTEKeys: roster.filter(p => p.pos === 'TE').map(p => p.normName),
      earlyTEKeys: new Set((s.earlyTEs || []).map(NS.normName)),
      bestSkillTier: skillTiers.length ? Math.min(...skillTiers) : Infinity,
      startable: PB.startableRemaining(state, available)
    };
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
