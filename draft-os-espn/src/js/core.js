// Shared namespace + tiny utilities. Every module attaches to globalThis.DraftOS
// and (in Node) exports the same namespace, so browser <script> concat and
// require() both work with zero tooling.
(function () {
  const NS = globalThis.DraftOS || (globalThis.DraftOS = {});

  NS.clone = obj => JSON.parse(JSON.stringify(obj));

  // Deterministic RNG (mulberry32) so simulator tests are reproducible.
  NS.makeRng = function (seed) {
    let a = seed >>> 0;
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  };

  NS.POSITIONS = ['QB', 'RB', 'WR', 'TE', 'K', 'DST'];
  NS.SKILL = ['RB', 'WR', 'TE'];

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
