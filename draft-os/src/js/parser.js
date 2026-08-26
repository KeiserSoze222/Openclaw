// Lenient parsers for every paste box. Pure functions, no DOM.
(function () {
  const NS = globalThis.DraftOS;
  const P = NS.parser = {};

  const POS_SET = new Set(['QB', 'RB', 'WR', 'TE', 'K', 'DST', 'DEF', 'D/ST', 'PK']);
  const normPos = p => {
    const u = String(p || '').toUpperCase();
    if (u === 'DEF' || u === 'D/ST') return 'DST';
    if (u === 'PK') return 'K';
    return u;
  };

  P.isTierBreak = function (line) {
    const t = line.trim();
    if (/^-{3,}$/.test(t) || /^={3,}$/.test(t)) return { tier: null };
    const m = t.match(/^tier\s*(\d+)\s*$/i);
    if (m) return { tier: parseInt(m[1], 10) };
    return null;
  };

  // Parse one queue line -> {rank, name, pos, team, bye} (pos/team/bye optional).
  P.parseQueueLine = function (line, byes) {
    const t = line.trim();
    if (!t) return null;
    let rank = null, name = '', pos = '', team = '', bye = null;
    const teamKeys = new Set(Object.keys(byes || {}));

    if (t.includes(',') && /^\d+\s*[.,]?/.test(t)) {
      // "12, Jahmyr Gibbs, RB, DET, 6"
      const parts = t.split(',').map(s => s.trim()).filter(s => s !== '');
      rank = parseInt(parts[0], 10);
      name = parts[1] || '';
      for (const part of parts.slice(2)) {
        const u = part.toUpperCase();
        if (POS_SET.has(u)) pos = normPos(u);
        else if (teamKeys.has(u)) team = u;
        else if (/^\d+$/.test(part)) bye = parseInt(part, 10);
        else if (!name) name = part;
      }
    } else {
      // "12. Jahmyr Gibbs" or "12 Jahmyr Gibbs RB DET 6"
      const m = t.match(/^(\d+)\s*[.)]?\s+(.*)$/);
      if (!m) return null;
      rank = parseInt(m[1], 10);
      let toks = m[2].split(/\s+/);
      // consume pos/team/bye off the tail, in any order
      let consumed = true;
      while (consumed && toks.length > 1) {
        consumed = false;
        const lastRaw = toks[toks.length - 1];
        const last = lastRaw.toUpperCase();
        if (bye === null && /^\d+$/.test(lastRaw)) { bye = parseInt(lastRaw, 10); toks.pop(); consumed = true; }
        else if (!team && teamKeys.has(last)) { team = last; toks.pop(); consumed = true; }
        else if (!pos && POS_SET.has(last)) { pos = normPos(last); toks.pop(); consumed = true; }
      }
      name = toks.join(' ');
    }
    if (!name || rank === null || isNaN(rank)) return null;
    return { rank, name, pos, team, bye };
  };

  // Full queue paste -> {players, strippedKeepers, warnings}
  // Tier breaks honored; without any, tiers default to blocks of `tierSize`.
  P.parseQueue = function (text, opts) {
    const byes = opts.byes;
    const keepers = opts.keepers || [];
    const tierSize = opts.tierSize || 12;
    const keeperKeys = new Set(keepers.map(k => NS.normName(k.player)));

    const players = [];
    const strippedKeepers = [];
    const warnings = [];
    let tier = 1, sawBreak = false;

    for (const line of String(text).split(/\r?\n/)) {
      const tb = P.isTierBreak(line);
      if (tb) {
        sawBreak = true;
        if (tb.tier !== null) tier = tb.tier;          // "TIER n"
        else if (players.length) tier += 1;            // "---" / "==="
        continue;
      }
      const p = P.parseQueueLine(line, byes);
      if (!p) {
        if (line.trim()) warnings.push({ line: line.trim(), reason: 'unparsed' });
        continue;
      }
      const key = NS.normName(p.name);
      if (keeperKeys.has(key)) { strippedKeepers.push(p.name); continue; }

      const badges = [];
      if (!p.pos) badges.push('needs data');
      if (!p.team) { if (!badges.includes('needs data')) badges.push('needs data'); }
      // Bye table always wins over a pasted bye column.
      if (p.team && byes[p.team] !== undefined) {
        if (p.bye !== null && p.bye !== byes[p.team]) badges.push('bye mismatch');
        p.bye = byes[p.team];
      } else if (p.bye === null) {
        if (!badges.includes('needs data')) badges.push('needs data');
      }
      players.push({
        rank: p.rank, name: p.name, normName: key, pos: p.pos, team: p.team,
        bye: p.bye, tier, tags: badges, marker: null, handcuffOf: null
      });
    }
    if (!sawBreak) {
      players.forEach(p => { p.tier = Math.ceil(p.rank / tierSize); });
    }
    players.sort((a, b) => a.rank - b.rank);
    return { players, strippedKeepers, warnings };
  };

  // ADP / FantasyPros paste: "rank name" per line. Availability/compare only.
  P.parseRankList = function (text, opts) {
    const keeperKeys = new Set(((opts && opts.keepers) || []).map(k => NS.normName(k.player)));
    const out = [];
    for (const line of String(text).split(/\r?\n/)) {
      const t = line.trim();
      if (!t) continue;
      const m = t.match(/^(\d+)\s*[.)]?\s*[,]?\s*(.+)$/);
      if (!m) continue;
      const name = m[2].split(',')[0].trim();
      const key = NS.normName(name);
      if (keeperKeys.has(key)) continue; // keepers stripped from every paste
      out.push({ rank: parseInt(m[1], 10), name, normName: key });
    }
    return out;
  };

  // Props: "PLAYER | PROP TYPE | LINE | NOTE"
  P.parseProps = function (text, opts) {
    const keeperKeys = new Set(((opts && opts.keepers) || []).map(k => NS.normName(k.player)));
    const out = [];
    for (const line of String(text).split(/\r?\n/)) {
      const t = line.trim();
      if (!t) continue;
      const parts = t.split('|').map(s => s.trim());
      if (parts.length < 2) continue;
      const [player, type, lineVal, note] = [parts[0], parts[1] || '', parts[2] || '', parts[3] || ''];
      const key = NS.normName(player);
      if (keeperKeys.has(key)) continue;
      const blob = `${type} ${lineVal} ${note}`.toLowerCase();
      let tag = null;
      if (/\b(over|sharp|volume)\b/.test(blob)) tag = 'money edge';
      if (/\b(under|fade)\b/.test(blob)) tag = 'fade';
      out.push({ player, normName: key, type, line: lineVal, note, tag });
    }
    return out;
  };

  // Catch-up paste: comma- or line-separated player names, in pick order.
  // With newlines, each line is one name (so "Last, First" lines survive);
  // a single line is split on commas.
  P.parseCatchup = function (text) {
    const s = String(text).trim();
    const parts = /\r?\n/.test(s) ? s.split(/\r?\n/) : s.split(',');
    return parts
      .map(x => x.trim().replace(/^\d+\s*[.)]?\s*/, ''))
      .filter(Boolean);
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
