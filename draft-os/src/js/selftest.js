// Engine self-tests (spec section 15 + Addendum B2). Deterministic fixtures,
// no simulator randomness except the seeded Monte Carlo test.
// Shared by `npm test` (node --test wrapper) and the in-page Run self-test button.
(function () {
  const NS = globalThis.DraftOS;
  const ST = NS.store;

  // ---- tiny assertion kit ---------------------------------------------------
  function makeT() {
    const results = [];
    let current = null;
    return {
      results,
      test(name, fn) {
        current = { name, pass: true, detail: '' };
        try { fn(); } catch (e) {
          current.pass = false;
          current.detail = String(e && e.message || e);
        }
        results.push(current);
      },
      ok(cond, msg) { if (!cond) throw new Error(msg || 'assertion failed'); },
      eq(a, b, msg) {
        if (JSON.stringify(a) !== JSON.stringify(b)) {
          throw new Error(`${msg || 'eq failed'}: ${JSON.stringify(a)} != ${JSON.stringify(b)}`);
        }
      }
    };
  }

  // ---- fixture helpers ------------------------------------------------------
  const fresh = () => ST.defaultState();

  function findQ(state, name) {
    const key = NS.normName(name);
    const p = state.myQueue.find(x => x.normName === key);
    if (!p) throw new Error(`fixture player not in queue: ${name}`);
    return p;
  }

  function pushPick(state, pick, player, byMe) {
    const team = NS.board.teamForPick(state, pick);
    state.picks.push({
      pick, team, player: player.name, pos: player.pos,
      normName: player.normName, keeper: false, byMe: !!byMe
    });
  }

  // Fill picks 1..through. My picks come from mine{pick:name}; other teams
  // consume `others` (real queue names, in order) then fall back to dummies
  // that don't touch my queue's availability.
  function fill(state, through, opts) {
    opts = opts || {};
    const mine = opts.mine || {};
    const others = (opts.others || []).slice();
    const filled = new Set(state.picks.map(p => p.pick));
    let dummy = 0;
    for (let pick = 1; pick <= through; pick++) {
      if (filled.has(pick)) continue;
      if (NS.board.isMyPick(state, pick)) {
        const name = mine[pick];
        if (!name) throw new Error(`fixture: my pick ${pick} needs a player`);
        pushPick(state, pick, findQ(state, name), true);
      } else if (others.length) {
        pushPick(state, pick, findQ(state, others.shift()), false);
      } else {
        dummy++;
        pushPick(state, pick, { name: `Opp Dummy ${dummy}`, pos: 'WR', normName: `opp dummy ${dummy}` }, false);
      }
    }
  }

  function fakeStorage() {
    const data = {};
    return {
      getItem: k => (k in data ? data[k] : null),
      setItem: (k, v) => { data[k] = String(v); },
      removeItem: k => { delete data[k]; },
      _data: data
    };
  }

  // ---- the suite ------------------------------------------------------------
  NS.runSelfTests = function () {
    const t = makeT();
    const KEEPER_PICKS = { 5: 'Bijan Robinson', 27: 'Josh Allen', 28: 'Brock Bowers', 35: 'Jaxon Smith-Njigba', 51: 'Drake Maye', 80: 'Jayden Daniels', 92: 'Rashee Rice', 143: 'Colston Loveland', 157: 'Quinshon Judkins', 159: 'Luther Burden III' };
    const MY_LIVE = [7, 14, 34, 47, 54, 67, 74, 87, 94, 107, 114, 127, 134, 147, 154, 167, 174, 187];

    t.test('pick order: exactly 190 picks', () => {
      const order = NS.pickorder.buildOrder(ST.defaultSettings());
      t.eq(order.length, 190);
    });

    t.test('pick order: keeper picks match the section-3 table (formula asserted)', () => {
      const s = ST.defaultSettings();
      const order = NS.pickorder.buildOrder(s);
      for (const [pickStr, player] of Object.entries(KEEPER_PICKS)) {
        const pick = Number(pickStr);
        const o = order[pick - 1];
        t.ok(o.keeper && o.keeper.player === player, `pick ${pick} should be keeper ${player}, got ${o.keeper && o.keeper.player}`);
        const k = s.keepers.find(k => k.player === player);
        const slot = s.teams.find(tm => tm.name === k.team).slot;
        t.eq(NS.pickorder.pickForSlotRound(slot, k.round, 10), pick, `formula for ${player}`);
      }
    });

    t.test('pick order: my live picks match the section-3 list', () => {
      const mp = NS.pickorder.myPicks(ST.defaultSettings());
      t.eq(mp.live, MY_LIVE);
      t.eq(mp.keeper, [27]);
    });

    t.test('pick order walk 26-30: 26 Hugo, 27/28 keeper-skip, 29 Bibhor, 30 Oskar; 34 mine, 35 skip; all keeper picks pre-filled', () => {
      const st = fresh();
      t.eq(NS.board.teamForPick(st, 26), 'Hugo');
      t.eq(NS.board.teamForPick(st, 29), 'Bibhor');
      t.eq(NS.board.teamForPick(st, 30), 'Oskar');
      const filled = new Set(st.picks.map(p => p.pick));
      [5, 27, 28, 35, 51, 80, 92, 143, 157, 159].forEach(k => t.ok(filled.has(k), `keeper pick ${k} pre-filled`));
      t.ok(NS.board.isMyPick(st, 34), 'pick 34 is mine');
      t.ok(filled.has(35), 'pick 35 (JSN) skipped');
      t.ok(!filled.has(34), 'pick 34 on the clock');
    });

    t.test('rule 1: pick 7 with a QB atop the queue -> QB skipped, R1 cited, primary is best RB/WR/TE', () => {
      const st = fresh();
      // Put Lamar at rank 1
      const lamar = findQ(st, 'Lamar Jackson');
      st.myQueue = [{ ...lamar, rank: 0 }].concat(st.myQueue.filter(p => p !== lamar));
      fill(st, 6, {});
      const rec = NS.recommend(st);
      t.eq(rec.pick, 7);
      t.ok(rec.myPick, 'pick 7 is mine');
      t.ok(NS.SKILL.includes(rec.primary.player.pos), `primary should be skill, got ${rec.primary.player.pos}`);
      const dnt = rec.doNotTake.find(d => d.player.normName === 'lamar jackson');
      t.ok(dnt && dnt.ruleId === 'R1', 'Lamar in do-not-take with R1');
    });

    t.test('rule 1 exception: Lamar available at pick 14 -> primary is Lamar, R1 cited', () => {
      const st = fresh();
      fill(st, 13, { mine: { 7: 'Jahmyr Gibbs' } });
      const rec = NS.recommend(st);
      t.eq(rec.pick, 14);
      t.eq(rec.primary.player.name, 'Lamar Jackson');
      t.ok(rec.primary.why.rules.includes('R1'), 'R1 cited');
    });

    t.test('rule 2: pick 34 default returns a pool QB', () => {
      const st = fresh();
      // Others take every tier-1/2 skill player so no fallen elite remains.
      const t12skill = st.myQueue.filter(p => p.tier <= 2 && NS.SKILL.includes(p.pos)).map(p => p.name);
      fill(st, 33, {
        mine: { 7: 'Jahmyr Gibbs', 14: "Ja'Marr Chase" },
        others: t12skill.filter(n => !['Jahmyr Gibbs', "Ja'Marr Chase"].includes(n))
      });
      const rec = NS.recommend(st);
      t.eq(rec.pick, 34);
      t.eq(rec.primary.player.name, 'Dak Prescott', 'highest-queued pool QB');
      t.ok(rec.primary.why.rules.includes('R2'), 'R2 cited');
    });

    t.test('rule 2 exception: fallen elite fires only when BOTH conditions hold', () => {
      // Case B: tier-1 skill (Gibbs) still there + 3+ startable QBs -> exception
      let st = fresh();
      fill(st, 33, { mine: { 7: 'James Cook', 14: "Ja'Marr Chase" } });
      let rec = NS.recommend(st);
      t.ok(NS.SKILL.includes(rec.primary.player.pos), 'fallen elite skill taken');
      t.ok(rec.primary.player.tier <= 2, 'fallen elite is tier 1-2');
      t.ok(rec.primary.why.rules.includes('R2'), 'R2 cited on exception');

      // Case C: tier cond holds but fewer than 3 startable QBs -> pool QB anyway
      st = fresh();
      st.myQueue = st.myQueue.filter(p => p.pos !== 'QB' || ['Dak Prescott', 'Lamar Jackson'].includes(p.name));
      fill(st, 33, { mine: { 7: 'James Cook', 14: "Ja'Marr Chase" }, others: ['Lamar Jackson'] });
      rec = NS.recommend(st);
      t.eq(rec.primary.player.name, 'Dak Prescott', 'exception blocked with <3 startable QBs');

      // Case D: 3+ QBs but no fallen elite (tier-1/2 skill all gone) -> pool QB
      st = fresh();
      const t12 = st.myQueue.filter(p => p.tier <= 2 && NS.SKILL.includes(p.pos)).map(p => p.name);
      fill(st, 33, { mine: { 7: 'Jahmyr Gibbs', 14: "Ja'Marr Chase" }, others: t12.filter(n => !['Jahmyr Gibbs', "Ja'Marr Chase"].includes(n)) });
      rec = NS.recommend(st);
      t.eq(rec.primary.player.name, 'Dak Prescott');
    });

    t.test('rule 3: QB2 with bye 7 (Herbert / Lawrence) forces QB at 67 and 74 + Week 7 alert; Dak does not', () => {
      for (const qb2 of [
        { name: 'Justin Herbert', team: 'LAC' },
        { name: 'Trevor Lawrence', team: 'JAX' }
      ]) {
        const st = fresh();
        st.myQueue.push({
          rank: 26.5, name: qb2.name, normName: NS.normName(qb2.name), pos: 'QB',
          team: qb2.team, bye: st.settings.byes[qb2.team], tier: 3, tags: [], marker: null, handcuffOf: null
        });
        fill(st, 47, { mine: { 7: 'Jahmyr Gibbs', 14: "Ja'Marr Chase", 34: qb2.name, 47: 'Puka Nacua' } });
        const status = NS.playbook.rule3Status(st);
        t.ok(status.collision, `${qb2.name}: collision detected`);
        t.ok(status.forced, `${qb2.name}: QB3 forced`);
        fill(st, 66, { mine: { 54: 'Jonathan Taylor' } });
        const rec = NS.recommend(st);
        t.eq(rec.pick, 67);
        t.eq(rec.primary.player.pos, 'QB', `${qb2.name}: rec at 67 must be a QB`);
        t.ok(rec.primary.why.rules.includes('R3'), 'R3 cited');
        t.ok(rec.week7Alert, 'Week 7 alert shown');
      }
      // Negative: Dak (bye 14) -> no collision, no forcing
      const st = fresh();
      fill(st, 47, { mine: { 7: 'Jahmyr Gibbs', 14: "Ja'Marr Chase", 34: 'Dak Prescott', 47: 'Puka Nacua' } });
      const status = NS.playbook.rule3Status(st);
      t.ok(!status.collision, 'Dak: no collision');
      fill(st, 66, { mine: { 54: 'Jonathan Taylor' } });
      const rec = NS.recommend(st);
      t.ok(!rec.week7Alert, 'no Week 7 alert for Dak');
    });

    t.test('rule 8: pick 100+ with 0 WR leans WR unless a player is 10+ ranks better', () => {
      // Case A: best RB only 5 ranks better -> lean WR
      let st = fresh();
      st.myQueue = st.myQueue.filter(p => p.rank <= 25); // trim fillers
      st.myQueue.push(
        { rank: 40, name: 'Late RB A', normName: 'late rb a', pos: 'RB', team: 'CHI', bye: 10, tier: 4, tags: [], marker: null, handcuffOf: null },
        { rank: 45, name: 'Late WR B', normName: 'late wr b', pos: 'WR', team: 'DET', bye: 6, tier: 4, tags: [], marker: null, handcuffOf: null }
      );
      const topNames = st.myQueue.filter(p => p.rank <= 25).map(p => p.name);
      const mine = { 7: 'Jahmyr Gibbs', 14: 'Christian McCaffrey', 34: 'Dak Prescott', 47: 'Jonathan Taylor', 54: 'James Cook', 67: 'Chase Brown', 74: 'Derrick Henry', 87: 'Saquon Barkley', 94: 'Trey McBride' };
      fill(st, 106, { mine, others: topNames.filter(n => !Object.values(mine).includes(n)) });
      let rec = NS.recommend(st);
      t.eq(rec.pick, 107);
      t.eq(NS.board.posCounts(NS.board.myRoster(st)).WR, 0, 'fixture has 0 WR');
      t.eq(rec.primary.player.name, 'Late WR B', 'leans WR');
      t.ok(rec.primary.why.rules.includes('R8'), 'R8 cited');

      // Case B: RB 12 ranks better -> take the RB (R8 exception)
      st = fresh();
      st.myQueue = st.myQueue.filter(p => p.rank <= 25);
      st.myQueue.push(
        { rank: 40, name: 'Late RB A', normName: 'late rb a', pos: 'RB', team: 'CHI', bye: 10, tier: 4, tags: [], marker: null, handcuffOf: null },
        { rank: 52, name: 'Late WR B', normName: 'late wr b', pos: 'WR', team: 'DET', bye: 6, tier: 4, tags: [], marker: null, handcuffOf: null }
      );
      fill(st, 106, { mine, others: topNames.filter(n => !Object.values(mine).includes(n)) });
      rec = NS.recommend(st);
      t.eq(rec.primary.player.name, 'Late RB A', 'R8 exception: 10+ ranks better');
    });

    t.test('rule 6: K/DST never recommended before 174; allowed at 174 and 187; never two of the same', () => {
      const st = fresh();
      const someK = st.myQueue.find(p => p.pos === 'K');
      const someD = st.myQueue.find(p => p.pos === 'DST');
      for (const pick of MY_LIVE.filter(p => p < 174)) {
        const rec = NS.recommend(st, { forPick: pick });
        for (const slot of ['primary', 'alt', 'panic']) {
          if (rec[slot]) t.ok(!['K', 'DST'].includes(rec[slot].player.pos), `${slot} at pick ${pick} is ${rec[slot].player.pos}`);
        }
      }
      const ctx7 = NS.playbook.buildCtx(st, 100);
      t.eq(NS.playbook.legality(st, ctx7, someK).ruleId, 'R6', 'K blocked before 174');
      t.eq(NS.playbook.legality(st, ctx7, someD).ruleId, 'R6', 'DST blocked before 174');

      // At 174 with neither rostered: primary is the higher-queued of K/DST
      const rec174 = NS.recommend(st, { forPick: 174 });
      t.ok(['K', 'DST'].includes(rec174.primary.player.pos), 'K/DST recommended at 174');
      t.ok(rec174.primary.why.rules.includes('R6'), 'R6 cited at 174');
      t.eq(rec174.primary.player.pos, someK.rank < someD.rank ? 'K' : 'DST', 'higher-queued first');

      // Roster the K; at 187 the DST is recommended, second K blocked
      const st2 = fresh();
      st2.picks.push({ pick: 174, team: 'Jeff K', player: someK.name, pos: 'K', normName: someK.normName, keeper: false, byMe: true });
      const rec187 = NS.recommend(st2, { forPick: 187 });
      t.eq(rec187.primary.player.pos, 'DST', 'the other one at 187');
      const otherK = st2.myQueue.filter(p => p.pos === 'K')[1];
      const ctx187 = NS.playbook.buildCtx(st2, 187);
      t.eq(NS.playbook.legality(st2, ctx187, otherK).ruleId, 'R6', 'second K blocked');
    });

    t.test('rule 7: IR stashes gated to 147+ / 187', () => {
      const st = fresh();
      st.myQueue.push(
        { rank: 61, name: 'Jordyn Tyson', normName: NS.normName('Jordyn Tyson'), pos: 'WR', team: 'ARI', bye: 14, tier: 6, tags: [], marker: null, handcuffOf: null },
        { rank: 62, name: 'Jayden Higgins', normName: NS.normName('Jayden Higgins'), pos: 'WR', team: 'HOU', bye: 8, tier: 6, tags: [], marker: null, handcuffOf: null }
      );
      const tyson = findQ(st, 'Jordyn Tyson'), higgins = findQ(st, 'Jayden Higgins');
      t.eq(NS.playbook.legality(st, NS.playbook.buildCtx(st, 134), tyson).ruleId, 'R7', 'Tyson blocked before 147');
      t.ok(NS.playbook.legality(st, NS.playbook.buildCtx(st, 147), tyson).legal, 'Tyson legal at 147');
      t.eq(NS.playbook.legality(st, NS.playbook.buildCtx(st, 174), higgins).ruleId, 'R7', 'Higgins blocked before 187');
      t.ok(NS.playbook.legality(st, NS.playbook.buildCtx(st, 187), higgins).legal, 'Higgins legal at 187');
    });

    t.test('rules 4/5: second TE only when both TEs are top-6 in my queue', () => {
      const st = fresh();
      st.myQueue.push(
        { rank: 61, name: 'MidTier TE X', normName: 'midtier te x', pos: 'TE', team: 'PIT', bye: 9, tier: 6, tags: [], marker: null, handcuffOf: null }
      );
      const mcbride = findQ(st, 'Trey McBride');
      st.picks.push({ pick: 47, team: 'Jeff K', player: mcbride.name, pos: 'TE', normName: mcbride.normName, keeper: false, byMe: true });
      const top6TE = st.myQueue.filter(p => p.pos === 'TE').sort((a, b) => a.rank - b.rank).slice(0, 6).map(p => p.normName);
      const goodTE2 = st.myQueue.find(p => p.pos === 'TE' && p.normName !== mcbride.normName && top6TE.includes(p.normName));
      const badTE2 = findQ(st, 'MidTier TE X');
      const ctx = NS.playbook.buildCtx(st, 100);
      t.ok(NS.playbook.legality(st, ctx, goodTE2).legal, 'top-6 TE2 legal');
      const v = NS.playbook.legality(st, ctx, badTE2);
      t.ok(!v.legal && (v.ruleId === 'R5' || v.ruleId === 'R4'), 'mid-tier TE2 blocked');
      t.eq(v.ruleId, 'R5', 'mid-tier TE2 cites R5');
    });

    t.test('keepers never appear in available or recs, even if pasted', () => {
      const st = fresh();
      const paste = '1. Josh Allen QB BUF 7\n2. Bijan Robinson RB ATL 11\n3. Jahmyr Gibbs RB DET 6\n4. Puka Nacua WR LAR 11';
      const parsed = NS.parser.parseQueue(paste, { byes: st.settings.byes, keepers: st.settings.keepers, tierSize: 12 });
      t.eq(parsed.players.length, 2, 'keepers stripped from paste');
      t.ok(parsed.strippedKeepers.includes('Josh Allen') && parsed.strippedKeepers.includes('Bijan Robinson'));
      const avail = NS.board.available(st);
      t.ok(!avail.some(p => p.normName === 'josh allen' || p.normName === 'bijan robinson'), 'not in available');
      const rec = NS.recommend(st, { forPick: 7 });
      t.ok(rec.primary.player.normName !== 'josh allen', 'never recommended');
    });

    t.test('undo restores exact prior state; storage round-trips full state', () => {
      const st = fresh();
      const before = JSON.stringify({ picks: st.picks, log: st.log });
      NS.store.snapshot(st);
      pushPick(st, 1, findQ(st, 'Jahmyr Gibbs'), false);
      st.log.push({ t: 'pick', msg: 'x' });
      t.ok(JSON.stringify({ picks: st.picks, log: st.log }) !== before, 'state changed');
      t.ok(NS.store.undo(st), 'undo ran');
      t.eq(JSON.stringify({ picks: st.picks, log: st.log }), before, 'exact prior state');

      const storage = fakeStorage();
      pushPick(st, 1, findQ(st, 'Jahmyr Gibbs'), false);
      NS.store.save(st, storage);
      const loaded = NS.store.load(storage);
      t.ok(!loaded.corrupt, 'load ok');
      t.eq(JSON.stringify(NS.store.exportable(loaded.state)), JSON.stringify(NS.store.exportable(st)), 'round-trip');
    });

    t.test('catch-up paste assigns across a snake turn and keeper picks (26-30)', () => {
      const st = fresh();
      fill(st, 25, { mine: { 7: 'Jahmyr Gibbs', 14: "Ja'Marr Chase" } });
      t.eq(NS.board.currentPick(st), 26);
      const names = NS.parser.parseCatchup('Derrick Henry, George Pickens, Nico Collins');
      const res = NS.board.assignCatchup(st, names);
      t.eq(res.unmatched.length, 0, 'all matched');
      t.eq(res.assignments.map(a => [a.pick, a.team]), [[26, 'Hugo'], [29, 'Bibhor'], [30, 'Oskar']], 'keeper picks 27/28 skipped');
    });

    t.test("name normalization: Ja'Marr Chase / JaMarr Chase / Chase, Ja'Marr all match", () => {
      const st = fresh();
      for (const variant of ["Ja'Marr Chase", 'JaMarr Chase', "Chase, Ja'Marr", 'ja marr chase', 'JAMARR CHASE']) {
        const m = NS.matchName(variant, st.myQueue);
        t.ok(m.kind === 'exact' && m.player.name === "Ja'Marr Chase", `variant "${variant}"`);
      }
      t.eq(NS.normName('Luther Burden III'), NS.normName('luther burden'), 'suffix stripped');
      t.eq(NS.normName('A.J. Brown'), 'aj brown', 'periods stripped');
    });

    t.test('bye table wins over a conflicting pasted bye column', () => {
      const st = fresh();
      const parsed = NS.parser.parseQueue('1. James Cook RB BUF 9', { byes: st.settings.byes, keepers: [], tierSize: 12 });
      t.eq(parsed.players[0].bye, 7, 'table bye (BUF=7) wins');
      t.ok(parsed.players[0].tags.includes('bye mismatch'), 'bye mismatch badge');
    });

    // ---- Addendum B2 extras -------------------------------------------------

    t.test('board counts include keepers from pick 1 (Andrew shows RB 1 pre-draft)', () => {
      const st = fresh();
      const tc = NS.board.teamCounts(st);
      t.eq(tc['Andrew'].RB, 1);
      t.eq(tc['Jeff K'].QB, 1);
      t.eq(tc['Nolan'].TE, 1);
      t.eq(tc['Mike'].WR, 1);
    });

    t.test('sample queue: tier breaks parse into tiers 1/2/3; filler removed on real paste', () => {
      const st = fresh();
      t.eq(findQ(st, 'Jahmyr Gibbs').tier, 1);
      t.eq(findQ(st, 'Lamar Jackson').tier, 2);
      t.eq(findQ(st, 'Derrick Henry').tier, 3);
      t.ok(st.myQueue.some(p => p.filler), 'fillers present in sample');
      const paste = Array.from({ length: 20 }, (_, i) => `${i + 1}. Real Player ${i + 1} WR DET 6`).join('\n');
      const parsed = NS.parser.parseQueue(paste, { byes: st.settings.byes, keepers: st.settings.keepers, tierSize: 12 });
      st.myQueue = parsed.players; st.usingSample = false;
      t.eq(st.myQueue.length, 20, 'paste replaces the whole queue');
      t.ok(!st.myQueue.some(p => p.filler), 'fillers gone');
    });

    t.test('Monte Carlo: protected Lamar survives to 14 at 100%; ADP-3 unprotected < 5%', () => {
      const st = fresh();
      fill(st, 7, { mine: { 7: 'Jahmyr Gibbs' } });
      NS.survival.clearCache();
      const mc1 = NS.survival.monteCarlo(st, { protect: ['Lamar Jackson'], n: 60, seed: 42, budgetMs: 5000, force: true });
      t.eq(mc1.targetPick, 14);
      t.eq(mc1.probs['lamar jackson'], 100, 'protected -> 100%');
      st.adp = NS.parser.parseRankList('1. Ja\'Marr Chase\n2. Puka Nacua\n3. Lamar Jackson\n4. Christian McCaffrey\n5. Jonathan Taylor', {});
      const mc2 = NS.survival.monteCarlo(st, { protect: [], n: 60, seed: 42, budgetMs: 5000, force: true });
      t.ok(mc2.probs['lamar jackson'] < 5, `ADP 3 unprotected -> <5% (got ${mc2.probs['lamar jackson']}%)`);
      NS.survival.clearCache();
    });

    t.test('build-path guard: 15 slots needed in 14 picks -> warning, 4th QB dropped first', () => {
      const st = fresh();
      st.settings.targets = { QB: 4, RB: 5, WR: 6, TE: 2, K: 1, DST: 1 }; // 19 slots
      fill(st, 53, { mine: { 7: 'Jahmyr Gibbs', 14: 'Jonathan Taylor', 34: 'Dak Prescott', 47: 'James Cook' } });
      // Roster: Allen(QB) + Dak(QB) + 3 RB. 14 live picks left from pick 54.
      // Needed: QB 2 + RB 2 + WR 6 + TE 2 + K 1 + DST 1 = 14... push to 15 by 0 RBs? recompute:
      st.settings.targets.RB = 6; // 20 slots -> needed 15
      const g = NS.buildpath.guard(st);
      t.eq(g.picksLeft, 14);
      t.ok(g.dropped.length >= 1, 'warning shown (targets relaxed)');
      t.eq(g.dropped[0], '4th QB', '4th QB dropped first');
      t.ok(g.reachable, 'reachable after relaxing');
    });

    t.test('safe mode: a thrown engine error is contained, not fatal', () => {
      const orig = NS.recommend;
      NS.recommend = () => { throw new Error('boom'); };
      const res = NS.safeRecommend(fresh());
      NS.recommend = orig;
      t.ok(res.engineError && res.engineError.includes('boom'), 'error captured');
    });

    t.test('state migration: a v1 blob loads under v2 without data loss', () => {
      const st = fresh();
      const v1 = {
        settings: { teams: st.settings.teams, mySlot: 7, rounds: 19, keepers: st.settings.keepers, byes: st.settings.byes, clockSeconds: 75 },
        myQueue: st.myQueue.slice(0, 10),
        picks: st.picks,
        log: [{ t: 'init', msg: 'old' }]
      };
      const migrated = NS.store.migrate(JSON.parse(JSON.stringify(v1)));
      t.eq(migrated.version, 2);
      t.eq(migrated.settings.clockSeconds, 75, 'user setting preserved');
      t.eq(migrated.myQueue.length, 10, 'queue preserved');
      t.eq(migrated.log[0].msg, 'old', 'log preserved');
      t.ok(migrated.settings.flags && migrated.settings.flags.monteCarlo === false, 'v2 flags added');
    });

    return t.results;
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
