// recommend(state) -> Rec for the ESPN 1QB room. Pure function of state.
// My queue order is the only value signal; playbook rules filter and override;
// the upside overlay may nudge inside a valid tie, strictly below the rules.
(function () {
  const NS = globalThis.DraftOS;
  const PB = NS.playbook;

  const why = (txt, rules) => ({ text: txt, rules: rules || [] });

  function propsFor(state, player) {
    return (state.props || []).filter(pr => pr.normName === player.normName);
  }

  function injuryTag(state, player) {
    const hit = (state.injuries || []).find(i => NS.normName(i.name) === player.normName);
    return hit ? hit.tag : null;
  }

  function decorate(state, player) {
    if (!player) return null;
    return { ...player, injury: injuryTag(state, player), props: propsFor(state, player) };
  }

  // Pick the primary among legal players for this pick.
  function choosePrimary(state, ctx, legal, available) {
    const pick = ctx.pick;
    const rulesFired = [];
    let primary = legal[0] || null;
    let note = primary ? `#${primary.rank} in your queue - best legal player` : 'no legal players left';

    // R4 - K/DST window: whichever of K/DST is missing, higher-queued first
    if (ctx.kdst.includes(pick)) {
      const wantK = ctx.counts.K === 0, wantD = ctx.counts.DST === 0;
      const cands = legal.filter(p => (p.pos === 'K' && wantK) || (p.pos === 'DST' && wantD));
      if (cands.length) {
        rulesFired.push('R4');
        return {
          primary: cands[0], rulesFired, override: true,
          note: `K/DST window (pick ${pick}) - ${cands[0].pos} is the ${wantK && wantD ? 'higher-queued need' : 'remaining need'}`
        };
      }
    }

    // R2 exception - my 5th live pick only: elite QB a full tier above skill
    const ex = PB.rule2Exception(state, ctx, available);
    if (ex.fires) {
      rulesFired.push('R2');
      return {
        primary: ex.candidate, rulesFired, override: true,
        note: `R2 exception (5th live pick): ${ex.candidate.name} (tier ${ex.candidate.tier}) is a full tier above the best remaining skill player (tier ${ex.bestSkillTier})`
      };
    }

    // A5 Avoid marker: push below any equal-tier alternative (never removed)
    if (primary && primary.marker === 'avoid') {
      const alt = legal.find(p => p !== primary && p.tier <= primary.tier && p.marker !== 'avoid');
      if (alt) {
        primary = alt;
        note = `${alt.name} over avoided ${legal[0].name} (equal tier)`;
      }
    }

    return { primary, note, rulesFired, override: false };
  }

  NS.recommend = function (state, opts) {
    opts = opts || {};
    const s = state.settings;
    const cur = NS.board.currentPick(state);
    if (cur === null) return { draftOver: true };
    const pick = opts.forPick || cur;
    const myPick = NS.board.isMyPick(state, pick);
    const nextMine = NS.pickorder.myNextLivePick(s, myPick ? pick + 1 : pick);
    const available = NS.board.available(state);
    const ctx = PB.buildCtx(state, pick);

    // Legality pass (playbook rules, then the R6 handcuff gate via overlay)
    const legal = [], blocked = [];
    for (const p of available) {
      const v = PB.legality(state, ctx, p);
      if (!v.legal) { blocked.push({ player: p, ruleId: v.ruleId, reason: v.reason }); continue; }
      const g = NS.overlay.hardGate(state, pick, p);
      if (g) { blocked.push({ player: p, ruleId: g.ruleId, reason: g.reason }); continue; }
      legal.push(p);
    }

    const startable = ctx.startable;
    const picksBetween = nextMine
      ? NS.pickorder.livePicksBetween(s, myPick ? pick : cur - 1, nextMine)
      : 0;

    const mc = (s.flags.monteCarlo && NS.sim)
      ? NS.survival.monteCarlo(state, { protect: (state.sim && state.sim.protect) || [] })
      : null;

    const survLabel = p => {
      if (mc && mc.probs[p.normName] !== undefined) {
        const pct = mc.probs[p.normName];
        return { label: pct >= 75 ? 'likely' : pct >= 35 ? 'coin-flip' : 'gone', prob: pct };
      }
      return { label: NS.survival.heuristic(state, p, pick, picksBetween), prob: null };
    };

    const survival = available.slice(0, 5).map(p => ({ player: decorate(state, p), ...survLabel(p) }));

    const scarcity = [];
    for (const pos of ['QB', 'RB', 'WR', 'TE']) {
      const posAvail = available.filter(p => p.pos === pos);
      if (posAvail.length >= 5) {
        const gap = posAvail[4].rank - posAvail[0].rank;
        scarcity.push({ pos, gap, cliff: gap > s.scarcityGap });
      } else if (posAvail.length > 0) {
        scarcity.push({ pos, gap: null, cliff: true, thin: posAvail.length });
      }
    }

    const notes = NS.board.runDetection(state);

    const base = {
      pick, round: ctx.round,
      team: NS.board.teamForPick(state, pick),
      myPick, nextMyPick: nextMine, picksUntilMine: picksBetween,
      startable, scarcity, survival, notes,
      monteCarlo: mc ? { n: mc.n, targetPick: mc.targetPick, capped: mc.capped } : null,
      ghost: !!state.ghost
    };

    if (!myPick) {
      const watch = legal.slice(0, 5).map(p => ({ player: decorate(state, p), ...survLabel(p) }));
      return { ...base, watch };
    }

    // On the clock ------------------------------------------------------------
    const chosen = choosePrimary(state, ctx, legal, available);
    // Upside overlay (R7): strictly below the playbook - a no-op whenever an
    // override or any of R1/R2/R3/R4/R8 decided this pick.
    const overlayHit = NS.overlay.apply(state, ctx, legal, chosen);
    if (overlayHit) {
      chosen.primary = overlayHit.primary;
      chosen.note = overlayHit.whyText;
      chosen.rulesFired.push(overlayHit.cite);
    }
    const primary = chosen.primary;

    // R5 - FIVE names: Primary + Alt2-Alt5, mixed positions, each with a why.
    const alts = legal.filter(p => p !== primary).slice(0, 4).map((p, i) => ({
      player: decorate(state, p),
      why: why(`Alt${i + 2}: next best legal (#${p.rank}, ${p.pos})`, [])
    }));

    const doNotTake = blocked.slice(0, 6).map(b => ({
      player: decorate(state, b.player), ruleId: b.ruleId, reason: b.reason
    }));

    const costOfWaiting = [];
    for (const pos of ['QB', 'RB', 'WR', 'TE']) {
      const now = available.find(p => p.pos === pos);
      if (!now) continue;
      const later = available.find(p => p.pos === pos && survLabel(p).label === 'likely');
      costOfWaiting.push({
        pos,
        text: later
          ? `pass on ${pos} now -> expected best ${pos} at pick ${nextMine || '-'} is ${later.name} (#${later.rank})`
          : `pass on ${pos} now -> no ${pos} is safe to your next pick`
      });
    }

    let reachOrWait = null;
    if (mc && primary && alts[0]) {
      const pP = mc.probs[primary.normName], pA = mc.probs[alts[0].player.normName];
      if (pP !== undefined || pA !== undefined) {
        reachOrWait = `Taking ${primary.name} now vs waiting: ${primary.name} survives ${pP ?? '?'}% / ${alts[0].player.name} survives ${pA ?? '?'}%`;
      }
    }

    // "ESPN queue should be:" - the five names in order, deduped (R5)
    const espnQueue = [];
    if (primary) espnQueue.push(primary.name);
    alts.forEach(a => { if (!espnQueue.includes(a.player.name)) espnQueue.push(a.player.name); });

    return {
      ...base,
      primary: primary ? { player: decorate(state, primary), why: why(chosen.note, chosen.rulesFired) } : null,
      alts,
      doNotTake, costOfWaiting, reachOrWait, espnQueue,
      rulesFired: chosen.rulesFired
    };
  };

  // Long-press "conflicts with playbook?" at the current pick.
  NS.conflictCheck = function (state, player) {
    const pick = NS.board.currentPick(state);
    if (pick === null) return { legal: true, note: 'draft over' };
    const ctx = PB.buildCtx(state, pick);
    const v = PB.legality(state, ctx, player);
    if (v.legal) {
      const g = NS.overlay.hardGate(state, pick, player);
      if (g) return { legal: false, ruleId: g.ruleId, note: `${g.ruleId}: ${g.reason}` };
      return { legal: true, note: `No conflict at pick ${pick}.` };
    }
    const rule = PB.ruleById(v.ruleId);
    return { legal: false, ruleId: v.ruleId, note: `${v.ruleId} (${rule ? rule.label : ''}): ${v.reason}` };
  };

  NS.nextPlan = function (state) {
    const s = state.settings;
    const next = NS.pickorder.myNextLivePick(s, NS.board.currentPick(state) || 999);
    if (!next) return 'Draft complete.';
    const rec = NS.recommend(state, { forPick: next });
    if (!rec || !rec.primary) return `Pick ${next}: best legal player in queue.`;
    const parts = [rec.primary.player.name];
    (rec.alts || []).slice(0, 2).forEach(a => parts.push(`else ${a.player.name}`));
    const counts = NS.board.posCounts(NS.board.myRoster(state));
    const needs = [];
    if (counts.QB < 1) needs.push('QB1 still open');
    else if (counts.QB < 2) needs.push('QB2 still open');
    if (counts.TE < 1) needs.push('TE empty');
    if (counts.RB === 0) needs.push('RB empty');
    if (counts.WR === 0) needs.push('WR empty');
    return `Pick ${next}: ${parts.join(', ')}${needs.length ? ` (${needs.join('; ')})` : ''}.`;
  };

  // Safe mode wrapper: the engine must never blank the app mid-draft.
  NS.safeRecommend = function (state, opts) {
    try {
      return NS.recommend(state, opts);
    } catch (e) {
      return { engineError: String(e && e.stack || e) };
    }
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
