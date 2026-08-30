// State schema, defaults, migration, undo, persistence for the ESPN app.
// STORAGE ISOLATION: every localStorage key is prefixed "espn:" so this app
// and the Yahoo Superflex app can never read or overwrite each other's state,
// even when served from the same origin.
(function () {
  const NS = globalThis.DraftOS;
  const ST = NS.store = {};

  ST.VERSION = 2;
  ST.KEY = 'espn:draftos_state_v2';
  ST.AUTOSAVE_KEY = 'espn:draftos_autosave';
  ST.UNDO_LIMIT = 30;

  ST.defaultSettings = function () {
    return {
      teams: NS.clone(NS.DATA.TEAMS),
      mySlot: NS.DATA.MY_SLOT,
      myLabel: 'KeiserSoze',
      rounds: NS.DATA.ROUNDS,
      roundsMin: NS.DATA.ROUNDS_MIN,
      roundsMax: NS.DATA.ROUNDS_MAX,
      keepers: NS.clone(NS.DATA.KEEPERS),   // rounds BLANK = not kept
      byes: NS.clone(NS.DATA.BYES),
      clockSeconds: 90,
      tierSize: 12,
      eliteQBs: NS.clone(NS.DATA.ELITE_QBS),
      earlyTEs: NS.clone(NS.DATA.EARLY_TES),
      qb3Pick: 130,
      startable: { QB: 15, RB: 30, WR: 36, TE: 12 },  // rule 9: 1QB startable QB = top 15
      targets: { QB: 2, RB: 5, WR: 5, TE: 1, K: 1, DST: 1 },
      scarcityGap: 15,
      survivalFactors: { likely: 1.0, coinflip: 0.5 },
      panicProb: 80,
      // rule 9 sim appetite for a 12-team 1QB room (editable)
      simQB: { firstQBStart: 4, firstQBEnd: 9, secondQBAfter: 10 },
      overlay: NS.overlay.defaults(),
      flags: {
        monteCarlo: false,
        roadmap: false,
        buildGuard: false,
        byeLoad: false,
        markers: true,       // rule 6 needs the handcuff marker usable
        resilience: false    // draft grade only
      }
    };
  };

  ST.buildSampleQueue = function (settings) {
    const parsed = NS.parser.parseQueue(NS.DATA.SAMPLE_QUEUE_TEXT, {
      byes: settings.byes, keepers: [], tierSize: settings.tierSize
    });
    const fillers = NS.DATA.buildFillers().map(f => ({
      ...f, normName: NS.normName(f.name), marker: null, handcuffOf: null
    }));
    return parsed.players.concat(fillers);
  };

  // Rebuild the keeper pre-fills from the current settings, preserving live
  // picks. The core of the setup-guard "full clean recompute": also re-derives
  // each live pick's team/byMe from the (possibly changed) draft order and
  // drops picks beyond the (possibly shrunk) round count or now owned by a
  // keeper.
  ST.recompute = function (state) {
    const total = NS.board.totalPicks(state);
    const keeperEntries = NS.board.keeperPickEntries(state);
    const keeperPicks = new Set(keeperEntries.map(k => k.pick));
    const me = NS.board.myTeamName(state.settings);
    const live = state.picks
      .filter(p => !p.keeper && !keeperPicks.has(p.pick) && p.pick <= total)
      .map(p => {
        const team = NS.board.teamForPick(state, p.pick);
        return { ...p, team, byMe: team === me };
      });
    state.picks = keeperEntries.concat(live).sort((a, b) => a.pick - b.pick);
    if (NS.survival && NS.survival.clearCache) NS.survival.clearCache();
    return state;
  };

  ST.defaultState = function () {
    const settings = ST.defaultSettings();
    const state = {
      version: ST.VERSION,
      settings,
      myQueue: null,
      usingSample: true,
      adp: [],
      props: [],
      propsText: '',
      fp: [],
      fpText: '',
      injuries: NS.clone(NS.DATA.INJURY_TAGS),
      picks: [],
      log: [{ t: 'init', msg: 'Draft OS (ESPN) initialized. Set your slot + draft order, then keeper rounds.' }],
      ghost: false,
      undoStack: [],
      sim: null,
      grade: null
    };
    state.myQueue = ST.buildSampleQueue(settings);
    NS.overlay.applyPreTags(state);
    state.picks = NS.board.keeperPickEntries(state);
    return state;
  };

  // ---- Migration ------------------------------------------------------------
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
    out.settings.overlay = { ...base.settings.overlay, ...((raw.settings || {}).overlay || {}) };
    out.settings.simQB = { ...base.settings.simQB, ...((raw.settings || {}).simQB || {}) };
    out.version = ST.VERSION;
    ST.validate(out);
    return NS.overlay.applyPreTags(out);
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

  // ---- Persistence (espn:-prefixed keys only) -------------------------------
  ST.save = function (state, storage) {
    const json = JSON.stringify(ST.exportable(state));
    try {
      const prev = storage.getItem(ST.KEY);
      if (prev) storage.setItem(ST.AUTOSAVE_KEY, prev);
      storage.setItem(ST.KEY, json);
    } catch (e) { /* quota - export button is the escape hatch */ }
    return json;
  };

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

  // ESPN pre-draft list: my queue as plain text, active keepers stripped,
  // K/DST at the bottom in order.
  ST.espnPreDraftList = function (state) {
    const kept = NS.board.activeKeeperKeys(state.settings);
    const q = state.myQueue.filter(p => !kept.has(p.normName));
    const skill = q.filter(p => !['K', 'DST'].includes(p.pos));
    const kdst = q.filter(p => ['K', 'DST'].includes(p.pos));
    return skill.concat(kdst).map(p => p.name).join('\n');
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
