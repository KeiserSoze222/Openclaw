// Upside overlay (rule R7). Same mechanics as the Yahoo app: only reorders
// LEGAL candidates in the same queue tier, within 6 ranks of the primary,
// among the top-3 legal - strictly below the playbook (stand-down set uses
// the ESPN rule ids). If a Target is later marked as someone's keeper, the
// keeper strip wins upstream with no error (he never reaches the overlay).
(function () {
  const NS = globalThis.DraftOS;
  const OV = NS.overlay = {};

  OV.RANK_WINDOW = 6;
  OV.TOP_N = 3;
  OV.HANDCUFF_GATE_PICK = 100;
  // ESPN rule ids that make the overlay stand down when they decided the pick.
  OV.RESPECTS = ['R1', 'R2', 'R3', 'R4', 'R8'];

  OV.defaults = function () {
    return {
      targets: [
        'Jadarian Price', 'Jaxson Dart', 'Tee Higgins', 'Malik Nabers',
        'Emeka Egbuka', 'Tucker Kraft', 'Jared Goff', 'Omarion Hampton',
        'Travis Etienne', 'Blake Corum', 'MarShawn Lloyd', "De'Zhaun Stribling"
      ],
      targetFrom: {},
      fades: ['Derrick Henry', 'Josh Jacobs', 'Kyle Pitts', 'Travis Kelce'],
      dualThreatQBs: ['Lamar Jackson', 'Jalen Hurts', 'Jaxson Dart', 'Caleb Williams'],
      handcuffs: {},   // no pre-set handcuffs in this league (rule 6: marker only)
      hardGates: []
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

  OV.applyPreTags = function (state) {
    (state.myQueue || []).forEach(p => {
      if (!p.handcuffOf) {
        const starter = OV.handcuffStarter(state, p.normName);
        if (starter) p.handcuffOf = starter;
      }
    });
    return state;
  };

  // Stack tags: rostering a QB tags his team's RB/WR/TE and vice versa.
  OV.isStacked = function (state, player) {
    if (!player.team) return false;
    const roster = NS.board.myRoster(state);
    const teamOf = entry => {
      const q = state.myQueue.find(x => x.normName === entry.normName);
      return q && q.team ? q.team : null;
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

  // Tiebreak priority, highest first. Fade automatically loses the tie.
  OV.score = function (state, pick, player) {
    const ov = cfg(state);
    const key = player.normName;
    if (normSet(ov.fades).has(key)) return { score: -1, tag: 'fade' };
    if (player.pos === 'QB' && normSet(ov.dualThreatQBs).has(key)) return { score: 5, tag: 'dual-threat' };
    if (OV.isTarget(state, pick, player)) return { score: 4, tag: 'target' };
    if ((state.props || []).some(pr => pr.normName === key && pr.tag === 'money edge')) return { score: 3, tag: 'money edge' };
    if (OV.isStacked(state, player)) return { score: 2, tag: 'stack' };
    if (player.handcuffOf) return { score: 1, tag: 'handcuff' };
    return { score: 0, tag: null };
  };

  // R6 hard gate: a USER-MARKED handcuff is not recommendable before overall
  // pick 100 - unless his starter went in the last 2 picks.
  OV.hardGate = function (state, pick, player) {
    const ov = cfg(state);
    for (const g of ov.hardGates || []) {
      if (NS.normName(g.name) === player.normName && pick < g.beforePick) {
        return { ruleId: 'R7', reason: `hard gate - never before pick ${g.beforePick}` };
      }
    }
    if (player.handcuffOf && pick < OV.HANDCUFF_GATE_PICK) {
      const sKey = NS.normName(player.handcuffOf);
      const recent = state.picks.some(x => x.normName === sKey && x.pick >= pick - 2 && x.pick < pick);
      if (!recent) {
        return { ruleId: 'R6', reason: `handcuff of ${player.handcuffOf} - not before pick ${OV.HANDCUFF_GATE_PICK} (unless the starter went in the last 2 picks)` };
      }
    }
    return null;
  };

  const lastName = n => String(n).split(' ').pop();

  // -> null | {primary, whyText, cite}
  OV.apply = function (state, ctx, legal, chosen) {
    if (!chosen || chosen.override) return null;
    if ((chosen.rulesFired || []).some(r => OV.RESPECTS.includes(r))) return null;
    const primary = chosen.primary;
    if (!primary || primary !== legal[0]) return null;

    const pick = ctx.pick;
    const group = legal.slice(0, OV.TOP_N).filter(p =>
      p.tier === primary.tier && Math.abs(p.rank - primary.rank) <= OV.RANK_WINDOW);
    if (group.length < 2) return null;

    const scored = group.map(p => ({ p, ...OV.score(state, pick, p) }));
    const pRow = scored.find(x => x.p === primary);
    let best = pRow;
    for (const x of scored) if (x.score > best.score) best = x;

    if (best.p !== primary && best.score > pRow.score) {
      const reason = pRow.tag === 'fade' ? 'fade' : best.tag;
      return {
        primary: best.p, cite: 'R7',
        whyText: `Upside overlay: ${lastName(best.p.name)} over ${lastName(primary.name)} (${reason})`
      };
    }

    // WR-over-RB preference in a scoreless two-player tie, from my 3rd live
    // pick on, suppressed when I have 0 RB (no rule-8 lean in this league).
    if (ctx.liveIndex >= 2 && group.length === 2) {
      const wrRow = scored.find(x => x.p.pos === 'WR');
      const rbRow = scored.find(x => x.p.pos === 'RB');
      if (wrRow && rbRow && primary === rbRow.p &&
        wrRow.score >= rbRow.score && ctx.counts.RB !== 0) {
        return {
          primary: wrRow.p, cite: 'R7',
          whyText: `Upside overlay: ${lastName(wrRow.p.name)} over ${lastName(rbRow.p.name)} (WR over RB)`
        };
      }
    }
    return null;
  };

  OV.tagsFor = function (state, pick, player) {
    const out = [];
    const ov = cfg(state);
    if (player.pos === 'QB' && normSet(ov.dualThreatQBs).has(player.normName)) out.push({ kind: 'dual', label: 'dual-threat', list: 'dualThreatQBs' });
    if (normSet(ov.targets).has(player.normName)) out.push({ kind: 'target', label: 'target', list: 'targets' });
    if (normSet(ov.fades).has(player.normName)) out.push({ kind: 'fade', label: 'fade', list: 'fades' });
    if (OV.isStacked(state, player)) out.push({ kind: 'stack', label: 'stack', list: null });
    return out;
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
