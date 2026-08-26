// State schema, defaults, migration, undo, persistence. Storage is injected
// (localStorage in the browser, a plain object in tests).
(function () {
  const NS = globalThis.DraftOS;
  const ST = NS.store = {};

  ST.VERSION = 2;
  ST.KEY = 'draftos_state_v2';
  ST.AUTOSAVE_KEY = 'draftos_autosave';
  ST.UNDO_LIMIT = 30;

  ST.defaultSettings = function () {
    return {
      teams: NS.clone(NS.DATA.TEAMS),
      mySlot: NS.DATA.MY_SLOT,
      rounds: NS.DATA.ROUNDS,
      keepers: NS.clone(NS.DATA.KEEPERS),
      byes: NS.clone(NS.DATA.BYES),
      clockSeconds: 90,
      tierSize: 12,
      qb2Pool: NS.clone(NS.DATA.QB2_POOL),
      irLate: NS.clone(NS.DATA.IR_LATE),
      irSeasonEnd: NS.clone(NS.DATA.IR_SEASON_END),
      irStashPick: 147,
      cheapQBPick: 134,
      startable: { QB: 18, RB: 30, WR: 36, TE: 12 },
      targets: { QB: 3, RB: 5, WR: 6, TE: 1, K: 1, DST: 1 },
      scarcityGap: 15,
      survivalFactors: { likely: 1.0, coinflip: 0.5 },
      panicProb: 80,
      simQB: { firstQBIn4: 0.7, secondQBByR8: 0.5 },
      // Addendum A features - all default OFF (Confirmed Defaults)
      flags: {
        monteCarlo: false,     // A1
        roadmap: false,        // A2
        buildGuard: false,     // A3
        byeLoad: false,        // A4
        markers: false,        // A5
        resilience: false      // A6 extras (confirm dialog, precompute)
      }
    };
  };

  ST.buildSampleQueue = function (settings) {
    const parsed = NS.parser.parseQueue(NS.DATA.SAMPLE_QUEUE_TEXT, {
      byes: settings.byes, keepers: settings.keepers, tierSize: settings.tierSize
    });
    const fillers = NS.DATA.buildFillers().map(f => ({
      ...f, normName: NS.normName(f.name), marker: null, handcuffOf: null
    }));
    return parsed.players.concat(fillers);
  };

  ST.defaultState = function () {
    const settings = ST.defaultSettings();
    return {
      version: ST.VERSION,
      settings,
      myQueue: ST.buildSampleQueue(settings),
      usingSample: true,
      adp: [],
      props: [],
      propsText: '',
      fp: [],
      fpText: '',
      injuries: NS.clone(NS.DATA.INJURY_TAGS),
      picks: NS.board.keeperPickEntries(settings),
      log: [{ t: 'init', msg: 'Draft OS initialized. Keepers pre-filled.' }],
      ghost: false,
      undoStack: [],
      sim: null,
      grade: null
    };
  };

  // ---- Migration ------------------------------------------------------------
  // v1 = any blob without version (or version 1). We keep every field the user
  // had and fill in whatever v2 added. Never silently wipe.
  ST.migrate = function (raw) {
    if (!raw || typeof raw !== 'object') throw new Error('not an object');
    const v = raw.version || 1;
    if (v > ST.VERSION) throw new Error(`state version ${v} is newer than app (${ST.VERSION})`);
    const base = ST.defaultState();
    const out = { ...base, ...raw };
    out.settings = { ...base.settings, ...(raw.settings || {}) };
    out.settings.flags = { ...base.settings.flags, ...((raw.settings || {}).flags || {}) };
    out.settings.startable = { ...base.settings.startable, ...((raw.settings || {}).startable || {}) };
    out.settings.targets = { ...base.settings.targets, ...((raw.settings || {}).targets || {}) };
    out.version = ST.VERSION;
    ST.validate(out);
    return out;
  };

  ST.validate = function (state) {
    if (!state || typeof state !== 'object') throw new Error('state is not an object');
    if (!Array.isArray(state.settings && state.settings.teams) || !state.settings.teams.length) {
      throw new Error('settings.teams missing');
    }
    if (!Array.isArray(state.myQueue)) throw new Error('myQueue missing');
    if (!Array.isArray(state.picks)) throw new Error('picks missing');
    return true;
  };

  // ---- Persistence ----------------------------------------------------------
  ST.save = function (state, storage) {
    const json = JSON.stringify(ST.exportable(state));
    try {
      const prev = storage.getItem(ST.KEY);
      if (prev) storage.setItem(ST.AUTOSAVE_KEY, prev);
      storage.setItem(ST.KEY, json);
    } catch (e) { /* iOS quota - export button is the escape hatch */ }
    return json;
  };

  // -> {state} | {corrupt:true, error, autosave: state|null, fresh: state}
  ST.load = function (storage) {
    const tryParse = key => {
      const raw = storage.getItem(key);
      if (!raw) return null;
      return ST.migrate(JSON.parse(raw));
    };
    try {
      const state = tryParse(ST.KEY);
      if (state) return { state };
      return { state: ST.defaultState(), fresh: true };
    } catch (e) {
      let autosave = null;
      try { autosave = tryParse(ST.AUTOSAVE_KEY); } catch (_) { /* both corrupt */ }
      return { corrupt: true, error: String(e), autosave, fresh: ST.defaultState() };
    }
  };

  // undoStack is excluded from export (it can get big); everything else rides.
  ST.exportable = function (state) {
    const { undoStack, ...rest } = state;
    return rest;
  };

  ST.importJson = function (json) {
    const parsed = JSON.parse(json);
    const state = ST.migrate(parsed);
    state.undoStack = [];
    return state;
  };

  // ---- Undo -----------------------------------------------------------------
  const SNAP_FIELDS = ['picks', 'log', 'myQueue', 'ghost', 'usingSample', 'grade'];

  ST.snapshot = function (state) {
    const snap = {};
    SNAP_FIELDS.forEach(f => { snap[f] = NS.clone(state[f]); });
    state.undoStack.push(snap);
    if (state.undoStack.length > ST.UNDO_LIMIT) state.undoStack.shift();
  };

  ST.undo = function (state) {
    const snap = state.undoStack.pop();
    if (!snap) return false;
    SNAP_FIELDS.forEach(f => { state[f] = snap[f]; });
    return true;
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
