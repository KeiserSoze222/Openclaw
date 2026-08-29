// Upside overlay (O1-O5). Always on. Runs AFTER playbook filters and need
// tilt, and may only reorder LEGAL candidates that are (a) in the same queue
// tier, (b) within 6 queue ranks of the current primary, and (c) among the
// top 3 legal candidates for this pick. It never fires when any of
// R1/R2/R3/R6/R8/R9 decided the pick (playbook always outranks it), never
// promotes across a tier boundary, and never touches keepers (they are never
// in the candidate pool).
(function () {
  const NS = globalThis.DraftOS;
  const OV = NS.overlay = {};

  OV.RANK_WINDOW = 6;
  OV.TOP_N = 3;
  OV.HANDCUFF_GATE_PICK = 100;
  // Playbook citations that make the overlay stand down for this pick.
  OV.RESPECTS = ['R1', 'R2', 'R3', 'R6', 'R8', 'R9'];

  // O2 defaults - stored by NAME in settings so they survive every queue
  // paste (lookups are by normalized name at scoring time).
  OV.defaults = function () {
    return {
      targets: [
        'Jadarian Price', 'Jaxson Dart', 'Tee Higgins', 'Malik Nabers',
        'Emeka Egbuka', 'Tucker Kraft', 'Jared Goff', 'Omarion Hampton',
        'Bhayshul Tuten', 'Travis Etienne', 'Blake Corum', 'MarShawn Lloyd',
        "De'Zhaun Stribling", 'Isaiah Likely', "D'Andre Swift", 'Brian Robinson'
      ],
      targetFrom: { 'Brian Robinson': 100 },
      fades: ['Derrick Henry', 'Josh Jacobs', 'Kyle Pitts', 'Travis Kelce'],
      dualThreatQBs: ['Lamar Jackson', 'Jalen Hurts', 'Jaxson Dart', 'Caleb Williams'],
      // O4 handcuff -> starter, for the pick-100 gate and the sim.
      handcuffs: {
        'Blake Corum': 'Kyren Williams',
        'MarShawn Lloyd': 'Josh Jacobs',
        'Mike Washington': 'Ashton Jeanty',
        'Brian Robinson': 'Bijan Robinson'
      },
      hardGates: [{ name: 'Jeremiyah Love', beforePick: 87 }]
    };
  };

  const cfg = state => (state.settings.overlay || (state.settings.overlay = OV.defaults()));
  const normSet = list => new Set((list || []).map(NS.normName));

  OV.handcuffStarter = function (state, normName) {
    const map = cfg(state).handcuffs || {};
    for (const [cuff, starter] of Object.entries(map)) {
      if (NS.normName(cuff) === normName) return starter;
    }
    return null;
  };

  // Re-apply name-based pre-tags to queue rows (only handcuffOf lives on the
  // row - the simulator reads it). Called on defaults, every paste, and load.
  OV.applyPreTags = function (state) {
    (state.myQueue || []).forEach(p => {
      if (!p.handcuffOf) {
        const starter = OV.handcuffStarter(state, p.normName);
        if (starter) p.handcuffOf = starter;
      }
    });
    return state;
  };

  // O3: stack tags, computed live from my roster. Rostering a QB tags his
  // team's RB/WR/TE; rostering a skill player tags his team's QBs. Allen
  // (BUF keeper) is rostered from pick 1, so BUF skill is tagged from pick 1.
  OV.isStacked = function (state, player) {
    if (!player.team) return false;
    const roster = NS.board.myRoster(state);
    const teamOf = entry => {
      const q = state.myQueue.find(x => x.normName === entry.normName);
      if (q && q.team) return q.team;
      const k = (state.settings.keepers || []).find(k => NS.normName(k.player) === entry.normName);
      return k ? k.nfl : null;
    };
    if (NS.SKILL.includes(player.pos)) {
      return roster.some(r => r.pos === 'QB' && teamOf(r) === player.team);
    }
    if (player.pos === 'QB') {
      return roster.some(r => NS.SKILL.includes(r.pos) && teamOf(r) === player.team);
    }
    return false;
  };

  OV.isTarget = function (state, pick, player) {
    if (player.marker === 'target') return true;
    const ov = cfg(state);
    if (!normSet(ov.targets).has(player.normName)) return false;
    for (const [name, from] of Object.entries(ov.targetFrom || {})) {
      if (NS.normName(name) === player.normName && pick < from) return false;
    }
    return true;
  };

  // O1 priority, highest first. Fade automatically loses the tie.
  OV.score = function (state, pick, player) {
    const ov = cfg(state);
    const key = player.normName;
    if (normSet(ov.fades).has(key)) return { score: -1, tag: 'fade' };
    if (player.pos === 'QB' && normSet(ov.dualThreatQBs).has(key)) return { score: 5, tag: 'dual-threat' };
    if (OV.isTarget(state, pick, player)) return { score: 4, tag: 'target' };
    if ((state.props || []).some(pr => pr.normName === key && pr.tag === 'money edge')) return { score: 3, tag: 'money edge' };
    if (OV.isStacked(state, player)) return { score: 2, tag: 'stack' };
    // Handcuff of ANY starter: mine and someone else's are EQUAL priority,
    // so two handcuffs fall through to queue order.
    if (player.handcuffOf || OV.handcuffStarter(state, key)) return { score: 1, tag: 'handcuff' };
    return { score: 0, tag: null };
  };

  // Hard gates (never a tiebreak): O2 named gates + the O4 pick-100 handcuff
  // gate. -> null | {ruleId, reason}
  OV.hardGate = function (state, pick, player) {
    const ov = cfg(state);
    for (const g of ov.hardGates || []) {
      if (NS.normName(g.name) === player.normName && pick < g.beforePick) {
        return { ruleId: 'O2', reason: `hard gate - never before pick ${g.beforePick}` };
      }
    }
    const starter = OV.handcuffStarter(state, player.normName);
    if (starter && pick < OV.HANDCUFF_GATE_PICK) {
      const sKey = NS.normName(starter);
      const starterIsKeeper = (state.settings.keepers || []).some(k => NS.normName(k.player) === sKey);
      if (!starterIsKeeper) {
        // last-2-picks unlock (keeper starters never unlock early - O4)
        const recent = state.picks.some(x => x.normName === sKey && x.pick >= pick - 2 && x.pick < pick);
        if (recent) return null;
      }
      return {
        ruleId: 'O4',
        reason: `handcuff of ${starter} - not before pick ${OV.HANDCUFF_GATE_PICK}` +
          (starterIsKeeper ? ' (starter is a keeper: no early unlock)' : '')
      };
    }
    return null;
  };

  const lastName = n => String(n).split(' ').pop();

  // The overlay decision. chosen comes from choosePrimary.
  // -> null | {primary, whyText, cite}
  OV.apply = function (state, ctx, legal, chosen) {
    if (!chosen || chosen.override) return null;
    if ((chosen.rulesFired || []).some(r => OV.RESPECTS.includes(r))) return null;
    const primary = chosen.primary;
    // Only act on a pure queue-order primary (e.g. not an A5 avoid demotion).
    if (!primary || primary !== legal[0]) return null;

    const pick = ctx.pick;
    const group = legal.slice(0, OV.TOP_N).filter(p =>
      p.tier === primary.tier && Math.abs(p.rank - primary.rank) <= OV.RANK_WINDOW);
    if (group.length < 2) return null;

    const scored = group.map(p => ({ p, ...OV.score(state, pick, p) }));
    const pRow = scored.find(x => x.p === primary);
    let best = pRow;
    for (const x of scored) if (x.score > best.score) best = x; // equals keep queue order

    if (best.p !== primary && best.score > pRow.score) {
      const reason = pRow.tag === 'fade' ? 'fade' : best.tag;
      return {
        primary: best.p, cite: 'O1',
        whyText: `Upside overlay: ${lastName(best.p.name)} over ${lastName(primary.name)} (${reason})`
      };
    }

    // O5: after pick 14, a scoreless WR-vs-RB tie prefers the WR - unless I
    // have 0 RB or a rule-8 lean toward RB is live (R8 firing already skips
    // the overlay; this covers a lean with an RB already atop the queue).
    if (pick > ctx.earlyPicks[1] && group.length === 2) {
      const wrRow = scored.find(x => x.p.pos === 'WR');
      const rbRow = scored.find(x => x.p.pos === 'RB');
      if (wrRow && rbRow && primary === rbRow.p &&
        wrRow.score >= rbRow.score &&
        ctx.counts.RB !== 0 &&
        !(ctx.lean && ctx.lean.pos === 'RB')) {
        return {
          primary: wrRow.p, cite: 'O5',
          whyText: `Upside overlay: ${lastName(wrRow.p.name)} over ${lastName(rbRow.p.name)} (WR over RB)`
        };
      }
    }
    return null;
  };

  // UI helper: overlay pills for one player (always on, unlike A5 markers).
  OV.tagsFor = function (state, pick, player) {
    const out = [];
    const ov = cfg(state);
    if (player.pos === 'QB' && normSet(ov.dualThreatQBs).has(player.normName)) out.push({ kind: 'dual', label: 'dual-threat', list: 'dualThreatQBs' });
    if (normSet(ov.targets).has(player.normName)) {
      const from = Object.entries(ov.targetFrom || {}).find(([n]) => NS.normName(n) === player.normName);
      out.push({ kind: 'target', label: from ? `target ${from[1]}+` : 'target', list: 'targets' });
    }
    if (normSet(ov.fades).has(player.normName)) out.push({ kind: 'fade', label: 'fade', list: 'fades' });
    if (OV.isStacked(state, player)) out.push({ kind: 'stack', label: 'stack', list: null });
    return out;
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
