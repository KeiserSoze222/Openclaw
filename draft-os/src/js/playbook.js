// The 10 hard playbook rules. Every recommendation cites ruleIds from here.
(function () {
  const NS = globalThis.DraftOS;
  const PB = NS.playbook = {};

  PB.RULES = [
    { ruleId: 'R1', label: 'Early picks are skill only', text: 'Picks 7 and 14 = RB/WR/TE only. EXCEPTION: take Lamar Jackson if available at 14.' },
    { ruleId: 'R2', label: 'Pick 34 = QB2', text: 'Pick 34 = QB2 by default from the pool. Fallen elite skill player only if a full tier above the remaining pool QBs AND 3+ startable QBs remain.' },
    { ruleId: 'R3', label: 'Week 7 QB collision', text: 'Any QB2 with a Week 7 bye collides with Allen. If QB2 has bye 7, force QB3 by pick 74 - recs at 67 and 74 must be a QB unless QB3 is already rostered.' },
    { ruleId: 'R4', label: 'Target build', text: '3 QB (4th only at pick 134+), 5 RB, 6 WR, 1 TE (2 only if both are top-6 TEs), 1 K, 1 DST.' },
    { ruleId: 'R5', label: 'No mid-tier TE2', text: 'TE2 is never a Freiermuth/Njoku/Kelce-tier player over a needed WR/RB/QB3.' },
    { ruleId: 'R6', label: 'K/DST timing', text: 'K and DST only at picks 174 and 187. Never a second K or DST.' },
    { ruleId: 'R7', label: 'IR stash timing', text: 'IR stashes only at pick 147+. Season-ending names only at pick 187.' },
    { ruleId: 'R8', label: 'Fill the empty side', text: 'After pick 34, with 0 WR or 0 RB, the next two skill picks lean the empty side unless a player is 10+ ranks better.' },
    { ruleId: 'R9', label: 'Value beats need', text: 'Value beats need when the player is a full tier above anyone at a needy spot.' },
    { ruleId: 'R10', label: 'Props never override', text: 'Props/Vegas tags never override rules 1-3 at picks 7, 14, 34.' }
  ];

  PB.ruleById = id => PB.RULES.find(r => r.ruleId === id);

  const LAMAR = 'lamar jackson';

  // My K/DST picks: my last two live picks (174 and 187 with default settings).
  PB.kdstPicks = function (settings) {
    const live = NS.pickorder.myPicks(settings).live;
    return live.slice(-2);
  };

  // Position rank inside the FULL queue (1 = best QB in my queue, etc.).
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
    const th = state.settings.startable; // {QB:18, RB:30, WR:36, TE:12}
    const posRank = PB.posRankMap(state.myQueue);
    const out = { QB: 0, RB: 0, WR: 0, TE: 0 };
    available.forEach(p => {
      if (out[p.pos] !== undefined && posRank[p.normName] <= (th[p.pos] || 999)) out[p.pos]++;
    });
    return out;
  };

  // Rule 3 status: QB2 with a Week 7 bye is rostered and QB3 is not yet.
  PB.rule3Status = function (state) {
    const roster = NS.board.myRoster(state);
    const myQBs = roster.filter(p => p.pos === 'QB');
    const byeOf = p => {
      const q = state.myQueue.find(x => x.normName === p.normName);
      if (q && q.bye != null) return q.bye;
      const k = (state.settings.keepers || []).find(k => NS.normName(k.player) === p.normName);
      if (k && k.nfl) return state.settings.byes[k.nfl];
      return null;
    };
    const week7QBs = myQBs.filter(q => byeOf(q) === 7);
    const collision = myQBs.length >= 2 && week7QBs.length >= 2;
    return {
      qbCount: myQBs.length,
      collision,
      forced: collision && myQBs.length < 3,
      collidingQB: collision ? week7QBs.map(q => q.player).filter(n => NS.normName(n) !== 'josh allen')[0] : null
    };
  };

  // Rule 2 helpers -----------------------------------------------------------
  PB.poolQBsAvailable = function (state, available) {
    const pool = new Set((state.settings.qb2Pool || []).map(NS.normName));
    return available.filter(p => p.pos === 'QB' && pool.has(p.normName));
  };

  // Fallen elite: tier 1-2 skill player, a full tier above the remaining pool
  // QBs, with 3+ startable QBs still on the board.
  PB.fallenElite = function (state, available) {
    const poolQBs = PB.poolQBsAvailable(state, available);
    const startable = PB.startableRemaining(state, available);
    const bestPoolTier = poolQBs.length ? Math.min(...poolQBs.map(q => q.tier)) : Infinity;
    const candidate = available.find(p =>
      NS.SKILL.includes(p.pos) && p.tier <= 2 && p.tier < bestPoolTier);
    const condTier = !!candidate;
    const condQBs = startable.QB >= 3;
    return {
      fires: condTier && condQBs && poolQBs.length > 0,
      candidate: candidate || null,
      condTier, condQBs,
      poolQBs, startableQBs: startable.QB
    };
  };

  // Rule 8 lean state at one of my picks: once a side (WR/RB) hits 0 after
  // pick 34, the lean covers my next TWO skill picks - even after the count
  // leaves zero. QB picks don't consume the window. If the side is still
  // empty when the window closes, the trigger re-arms.
  // -> {pos:'WR'|'RB', remaining:1|2} | null
  PB.computeLean = function (state, pick) {
    const live = NS.pickorder.myPicks(state.settings).live;
    const qb2Pick = live[2];
    if (!(pick > qb2Pick)) return null;
    const roster = NS.board.myRoster(state);
    let lean = null;
    for (const q of live.filter(q => q > qb2Pick && q <= pick)) {
      if (!lean) {
        const counts = NS.board.posCounts(roster.filter(r => r.pick < q));
        if (counts.WR === 0) lean = { pos: 'WR', remaining: 2 };
        else if (counts.RB === 0) lean = { pos: 'RB', remaining: 2 };
      }
      if (q === pick) return lean;
      const made = roster.find(r => r.pick === q);
      if (made && NS.SKILL.includes(made.pos) && lean) {
        lean.remaining--;
        if (lean.remaining <= 0) lean = null;
      }
    }
    return lean;
  };

  // Legality of one player at one pick. -> {legal:true} | {legal:false, ruleId, reason}
  // ctx: {pick, counts, top6TEKeys, kdst:[p1,p2], rule3}
  PB.legality = function (state, ctx, player) {
    const s = state.settings;
    const pick = ctx.pick;
    const counts = ctx.counts;

    // R6 - K/DST timing
    if (player.pos === 'K' || player.pos === 'DST') {
      if (!ctx.kdst.includes(pick)) {
        return { legal: false, ruleId: 'R6', reason: `K/DST only at picks ${ctx.kdst.join(' and ')}` };
      }
      if (counts[player.pos] >= 1) {
        return { legal: false, ruleId: 'R6', reason: `never a second ${player.pos}` };
      }
    }

    // R7 - IR stash timing
    const irLate = (s.irLate || []).map(NS.normName);
    const irEnd = (s.irSeasonEnd || []).map(NS.normName);
    const lastPick = ctx.kdst[ctx.kdst.length - 1];
    if (irEnd.includes(player.normName) && pick < lastPick) {
      return { legal: false, ruleId: 'R7', reason: `season-ending stash - pick ${lastPick} only` };
    }
    if (irLate.includes(player.normName) && pick < s.irStashPick) {
      return { legal: false, ruleId: 'R7', reason: `IR stash - pick ${s.irStashPick}+ only` };
    }

    // R1 - picks 7 and 14 skill only (Lamar exception at 14)
    if (ctx.earlyPicks.includes(pick) && !NS.SKILL.includes(player.pos)) {
      const isLamar = player.normName === LAMAR;
      if (!(pick === ctx.earlyPicks[1] && isLamar)) {
        return { legal: false, ruleId: 'R1', reason: `pick ${pick} = RB/WR/TE only` };
      }
    }

    // R4 - QB count caps
    if (player.pos === 'QB') {
      if (counts.QB >= 4) return { legal: false, ruleId: 'R4', reason: 'never a 5th QB' };
      if (counts.QB >= 3 && pick < s.cheapQBPick) {
        return { legal: false, ruleId: 'R4', reason: `4th QB only at pick ${s.cheapQBPick}+` };
      }
    }

    // R4/R5 - TE2 gate
    if (player.pos === 'TE' && counts.TE >= 1) {
      if (counts.TE >= 2) return { legal: false, ruleId: 'R4', reason: 'never a 3rd TE' };
      const rosterTE = ctx.myTEKeys[0];
      const bothTop6 = ctx.top6TEKeys.has(player.normName) &&
        (rosterTE === undefined || ctx.top6TEKeys.has(rosterTE));
      if (!bothTop6) {
        const rid = ctx.top6TEKeys.has(player.normName) ? 'R4' : 'R5';
        return { legal: false, ruleId: rid, reason: 'TE2 only if both TEs are top-6 in my queue' };
      }
    }

    return { legal: true };
  };

  // Build the legality context once per pick.
  PB.buildCtx = function (state, pick) {
    const s = state.settings;
    const roster = NS.board.myRoster(state);
    const counts = NS.board.posCounts(roster);
    const queueTEs = state.myQueue.filter(p => p.pos === 'TE').sort((a, b) => a.rank - b.rank);
    const top6TEKeys = new Set(queueTEs.slice(0, 6).map(t => t.normName));
    const myTEKeys = roster.filter(p => p.pos === 'TE').map(p => p.normName);
    const live = NS.pickorder.myPicks(s).live;
    return {
      pick, counts, top6TEKeys, myTEKeys,
      kdst: PB.kdstPicks(s),
      earlyPicks: live.slice(0, 2),         // 7 and 14 with default settings
      qb2Pick: live[2],                     // 34
      rule3Picks: [live[5], live[6]],       // 67 and 74
      rule3: PB.rule3Status(state),
      lean: PB.computeLean(state, pick)
    };
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
