// recommend(state) -> Rec. Pure function of state; no DOM, no network.
// My queue order is the only value signal. Playbook rules filter and override.
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
    return {
      ...player,
      injury: injuryTag(state, player),
      props: propsFor(state, player),
      allenStack: player.team === 'BUF' && ['WR', 'TE', 'RB'].includes(player.pos)
    };
  }

  // Pick the primary/alt among legal players for this pick.
  function choosePrimary(state, ctx, legal, available) {
    const s = state.settings;
    const pick = ctx.pick;
    const rulesFired = [];
    let primary = legal[0] || null;
    let note = primary ? `#${primary.rank} in your queue - best legal player` : 'no legal players left';

    // R6 - K/DST picks: recommend whichever of K/DST is missing (higher-queued first)
    if (ctx.kdst.includes(pick)) {
      const wantK = ctx.counts.K === 0, wantD = ctx.counts.DST === 0;
      const cands = legal.filter(p =>
        (p.pos === 'K' && wantK) || (p.pos === 'DST' && wantD));
      if (cands.length) {
        primary = cands[0]; // legal is queue-ordered; higher in queue wins
        rulesFired.push('R6');
        note = `K/DST window (pick ${pick}) - ${primary.pos} is the ${wantK && wantD ? 'higher-queued need' : 'remaining need'}`;
        return { primary, note, rulesFired, override: true };
      }
    }

    // R1 - Lamar exception at pick 14
    if (pick === ctx.earlyPicks[1]) {
      const lamar = legal.find(p => p.normName === 'lamar jackson');
      if (lamar) {
        rulesFired.push('R1');
        return { primary: lamar, note: `R1 exception: Lamar Jackson available at pick ${pick}`, rulesFired, override: true };
      }
    }

    // R3 - forced QB at 67/74 while the Week 7 collision is unresolved
    if (ctx.rule3.forced && ctx.rule3Picks.includes(pick)) {
      const qb = legal.find(p => p.pos === 'QB');
      if (qb) {
        rulesFired.push('R3');
        return {
          primary: qb, rulesFired, override: true,
          note: `R3: QB2 (${ctx.rule3.collidingQB || 'bye-7 QB'}) collides with Allen's Week 7 bye - QB3 forced by pick ${ctx.rule3Picks[1]}`
        };
      }
    }

    // R2 - pick 34 QB2 logic (only while I still need a QB2)
    if (pick === ctx.qb2Pick && ctx.counts.QB < 2) {
      const fe = PB.fallenElite(state, available);
      if (fe.fires) {
        rulesFired.push('R2', 'R9');
        return {
          primary: fe.candidate, rulesFired, override: true, fallenElite: fe,
          note: `R2 exception: ${fe.candidate.name} (tier ${fe.candidate.tier}) is a full tier above the remaining pool QBs and ${fe.startableQBs} startable QBs remain`
        };
      }
      if (fe.poolQBs.length) {
        rulesFired.push('R2');
        return {
          primary: fe.poolQBs[0], rulesFired, override: true, fallenElite: fe,
          note: `R2: pick ${pick} = QB2 - ${fe.poolQBs[0].name} is the highest-queued pool QB` +
            (fe.condTier && !fe.condQBs ? ` (fallen elite blocked: only ${fe.startableQBs} startable QBs left)` : '')
        };
      }
      const anyQB = legal.find(p => p.pos === 'QB');
      if (anyQB) {
        rulesFired.push('R2');
        return { primary: anyQB, rulesFired, override: true, note: `R2: pick ${pick} = QB2 - no pool QB left, best queue QB instead` };
      }
    }

    // R8 - lean the empty side after pick 34 (R9 tier value can override)
    if (primary && pick > ctx.qb2Pick) {
      let leanPos = null;
      if (ctx.counts.WR === 0) leanPos = 'WR';
      else if (ctx.counts.RB === 0) leanPos = 'RB';
      if (leanPos && primary.pos !== leanPos) {
        const bestLean = legal.find(p => p.pos === leanPos);
        if (bestLean) {
          if (primary.tier < bestLean.tier) {
            rulesFired.push('R9');
            note = `R9: ${primary.name} is a full tier above the best ${leanPos} (${bestLean.name}) despite 0 ${leanPos} rostered`;
          } else if (bestLean.rank - primary.rank >= 10) {
            rulesFired.push('R8');
            note = `R8 exception: ${primary.name} is ${bestLean.rank - primary.rank} ranks better than the best ${leanPos}`;
          } else {
            primary = bestLean;
            rulesFired.push('R8');
            note = `R8: 0 ${leanPos} rostered - leaning ${leanPos} (${bestLean.name}, #${bestLean.rank})`;
          }
        }
      }
    }

    // R2 bookkeeping: at pick 34 with QB2 already rostered, cite R2 as satisfied
    if (pick === ctx.qb2Pick && ctx.counts.QB >= 2 && primary) {
      rulesFired.push('R2');
      note += ' (R2 satisfied - QB2 already rostered)';
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

  // Main entry. opts.forPick lets the precompute path aim at a future pick.
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

    // Legality pass
    const legal = [], blocked = [];
    for (const p of available) {
      const v = PB.legality(state, ctx, p);
      if (v.legal) legal.push(p);
      else blocked.push({ player: p, ruleId: v.ruleId, reason: v.reason });
    }

    // Shared panels (used on and off the clock)
    const startable = PB.startableRemaining(state, available);
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

    // Scarcity cliff: gap between best and 5th-best available per position
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
    const qbComp = NS.board.qb2Competition(state);
    if (qbComp !== null && ctx.counts.QB < 2) notes.push(`${qbComp} teams could take a QB before pick ${ctx.qb2Pick}`);

    const rule3 = ctx.rule3;
    const week7Alert = rule3.collision
      ? `WEEK 7 COLLISION: ${rule3.collidingQB || 'a rostered QB'} shares Allen's Week 7 bye.` +
        (rule3.forced ? ` QB3 is forced at picks ${ctx.rule3Picks.join('/')}.` : ' QB3 rostered - resolved.')
      : null;

    const base = {
      pick, round: NS.pickorder.slotForPick(pick, s.teams.length).round,
      team: NS.board.teamForPick(state, pick),
      myPick, nextMyPick: nextMine, picksUntilMine: picksBetween,
      startable, scarcity, survival, notes, week7Alert,
      monteCarlo: mc ? { n: mc.n, targetPick: mc.targetPick, capped: mc.capped } : null,
      ghost: !!state.ghost
    };

    if (!myPick) {
      // Watch list: my top 5 legal targets for my next pick, with risk
      const watch = legal.slice(0, 5).map(p => ({ player: decorate(state, p), ...survLabel(p) }));
      return { ...base, watch };
    }

    // On the clock ------------------------------------------------------------
    const chosen = choosePrimary(state, ctx, legal, available);
    const primary = chosen.primary;
    const altPool = legal.filter(p => p !== primary);
    const alt = altPool[0] || null;

    // Panic: highest-ranked legal player very likely still there if I hesitate
    const panicTh = s.panicProb || 80;
    const panic = legal.find(p => {
      const sl = survLabel(p);
      return sl.prob !== null ? sl.prob >= panicTh : sl.label === 'likely';
    }) || null;

    // Do-not-take list for this pick (top blocked players by queue rank)
    const doNotTake = blocked.slice(0, 6).map(b => ({
      player: decorate(state, b.player), ruleId: b.ruleId, reason: b.reason
    }));

    // Cost of waiting per position of interest
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

    // Reach-or-wait line (A1)
    let reachOrWait = null;
    if (mc && primary && alt) {
      const pP = mc.probs[primary.normName], pA = mc.probs[alt.normName];
      if (pP !== undefined || pA !== undefined) {
        reachOrWait = `Taking ${primary.name} now vs waiting: ${primary.name} survives ${pP ?? '?'}% / ${alt.name} survives ${pA ?? '?'}%`;
      }
    }

    const allRules = chosen.rulesFired.slice();
    return {
      ...base,
      primary: primary ? { player: decorate(state, primary), why: why(chosen.note, allRules) } : null,
      alt: alt ? { player: decorate(state, alt), why: why(`next best legal (#${alt.rank})`, []) } : null,
      panic: panic ? { player: decorate(state, panic), why: why('highest-ranked legal player very likely still there if you hesitate', []) } : null,
      doNotTake, costOfWaiting, reachOrWait,
      rulesFired: allRules
    };
  };

  // Long-press "conflicts with playbook?" for any player at the current pick.
  NS.conflictCheck = function (state, player) {
    const pick = NS.board.currentPick(state);
    if (pick === null) return { legal: true, note: 'draft over' };
    const ctx = PB.buildCtx(state, pick);
    const v = PB.legality(state, ctx, player);
    if (v.legal) return { legal: true, note: `No conflict at pick ${pick}.` };
    const rule = PB.ruleById(v.ruleId);
    return { legal: false, ruleId: v.ruleId, note: `${v.ruleId} (${rule ? rule.label : ''}): ${v.reason}` };
  };

  // One-sentence Next Plan after each of my picks.
  NS.nextPlan = function (state) {
    const s = state.settings;
    const next = NS.pickorder.myNextLivePick(s, NS.board.currentPick(state) || 999);
    if (!next) return 'Draft complete.';
    const rec = NS.recommend(state, { forPick: next });
    if (!rec || !rec.primary) return `Pick ${next}: best legal player in queue.`;
    const parts = [rec.primary.player.name];
    if (rec.alt) parts.push(`else ${rec.alt.player.name}`);
    if (rec.panic && rec.panic.player.name !== (rec.alt && rec.alt.player.name)) {
      parts.push(`else ${rec.panic.player.name}`);
    }
    const counts = NS.board.posCounts(NS.board.myRoster(state));
    const needs = [];
    if (counts.QB < 2) needs.push('QB2 still open');
    else if (counts.QB < 3) needs.push('QB3 still open');
    if (counts.TE < 1) needs.push('TE empty');
    if (counts.RB === 0) needs.push('RB empty');
    if (counts.WR === 0) needs.push('WR empty');
    return `Pick ${next}: ${parts.join(', ')}${needs.length ? ` (${needs.join('; ')})` : ''}.`;
  };

  // Safe mode wrapper (A6): the engine must never blank the app mid-draft.
  NS.safeRecommend = function (state, opts) {
    try {
      return NS.recommend(state, opts);
    } catch (e) {
      return { engineError: String(e && e.stack || e) };
    }
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
