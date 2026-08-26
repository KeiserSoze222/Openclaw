// Name normalization + fuzzy matching. Used by every paste path.
// Never silently drops a low-confidence match — callers get a suggestion.
(function () {
  const NS = globalThis.DraftOS;

  const SUFFIXES = new Set(['jr', 'sr', 'ii', 'iii', 'iv', 'v']);

  // "Chase, Ja'Marr" -> "Ja'Marr Chase"; case/punct/suffix-insensitive key.
  NS.normName = function (raw) {
    let s = String(raw || '').trim();
    // "Last, First" (a single comma with words on both sides, no digits)
    const m = s.match(/^([^,\d]+),\s*([^,\d]+)$/);
    if (m) s = `${m[2]} ${m[1]}`;
    s = s.toLowerCase()
      .replace(/[.'’]/g, '')     // periods + apostrophes vanish: A.J. -> aj, Ja'Marr -> jamarr
      .replace(/[^a-z0-9]+/g, ' ')    // everything else becomes a space
      .trim();
    const toks = s.split(' ').filter(t => t && !SUFFIXES.has(t));
    return toks.join(' ');
  };

  function levenshtein(a, b) {
    if (a === b) return 0;
    const dp = Array.from({ length: a.length + 1 }, (_, i) => [i]);
    for (let j = 0; j <= b.length; j++) dp[0][j] = j;
    for (let i = 1; i <= a.length; i++) {
      for (let j = 1; j <= b.length; j++) {
        dp[i][j] = Math.min(
          dp[i - 1][j] + 1, dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1)
        );
      }
    }
    return dp[a.length][b.length];
  }
  NS.levenshtein = levenshtein;

  // Match a pasted name against a list of {name, normName}.
  // -> {kind:'exact'|'suggest'|'none', player?, suggestions?}
  NS.matchName = function (raw, players) {
    const key = NS.normName(raw);
    if (!key) return { kind: 'none', suggestions: [] };
    const exact = players.find(p => p.normName === key);
    if (exact) return { kind: 'exact', player: exact };
    // substring containment (e.g. "gibbs" or "jahmyr gibbs det")
    const contains = players.filter(p =>
      p.normName.includes(key) || key.includes(p.normName));
    if (contains.length === 1) return { kind: 'exact', player: contains[0] };
    // fuzzy: small edit distance relative to length
    const scored = players
      .map(p => ({ p, d: levenshtein(key, p.normName) }))
      .filter(x => x.d <= Math.max(2, Math.floor(key.length / 4)))
      .sort((a, b) => a.d - b.d);
    if (scored.length && scored[0].d <= 2 && (!scored[1] || scored[1].d > scored[0].d)) {
      return { kind: 'exact', player: scored[0].p };
    }
    const sugg = (contains.length ? contains : scored.map(x => x.p)).slice(0, 3);
    return { kind: sugg.length ? 'suggest' : 'none', suggestions: sugg };
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
