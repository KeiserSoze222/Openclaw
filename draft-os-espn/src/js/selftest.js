// Engine self-tests for the ESPN 12-team 1QB app. Deterministic fixtures.
// Shared by `npm test` (node --test wrapper) and the in-page Run self-test.
(function () {
  const NS = globalThis.DraftOS;
  const ST = NS.store;

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

  const fresh = () => ST.defaultState();

  function findQ(state, name) {
    const key = NS.normName(name);
    const p = state.myQueue.find(x => x.normName === key);
    if (!p) throw new Error(`fixture player not in queue: ${name}`);
    return p;
  }

  function addQ(state, rank, name, pos, team, tier) {
    const p = {
      rank, name, normName: NS.normName(name), pos, team,
      bye: state.settings.byes[team] ?? null, tier: tier || 6,
      tags: [], marker: null, handcuffOf: null
    };
    state.myQueue.push(p);
    return p;
  }

  function pushPick(state, pick, player, byMe) {
    const team = NS.board.teamForPick(state, pick);
    state.picks.push({
      pick, team, player: player.name, pos: player.pos,
      normName: player.normName, keeper: false, byMe: !!byMe
    });
  }

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

  function fakeStorage(seed) {
    const data = Object.assign({}, seed || {});
    return {
      getItem: k => (k in data ? data[k] : null),
      setItem: (k, v) => { data[k] = String(v); },
      removeItem: k => { delete data[k]; },
      _data: data
    };
  }

  NS.runSelfTests = function () {
    const t = makeT();
    // Default order: Joe(1) Rhett(2) Mike(3) Jeff(4=ME) TC(5) Max(6) Dan(7)
    // Pat(8) Jim(9) Ger(10) Team 11(11) Team 12(12). 16 rounds, no active keepers.
    const MY_LIVE_DEFAULT = [4, 21, 28, 45, 52, 69, 76, 93, 100, 117, 124, 141, 148, 165, 172, 189];

    t.test('pick order: slot 7, 12 teams, 16 rounds -> 192 picks + my numbers; rounds=14 recomputes', () => {
      const s = ST.defaultSettings();
      s.mySlot = 7;
      const order = NS.pickorder.buildOrder(s);
      t.eq(order.length, 192);
      t.eq(NS.pickorder.myPicks(s).live,
        [7, 18, 31, 42, 55, 66, 79, 90, 103, 114, 127, 138, 151, 162, 175, 186]);
      s.rounds = 14;
      t.eq(NS.pickorder.buildOrder(s).length, 168, '14 rounds -> 168 picks');
      t.eq(NS.pickorder.myPicks(s).live,
        [7, 18, 31, 42, 55, 66, 79, 90, 103, 114, 127, 138, 151, 162], 'my picks recompute');
    });

    t.test('default state: my picks at slot 4 (Jeff = KeiserSoze), no active keepers, blank rounds preloaded', () => {
      const st = fresh();
      t.eq(NS.pickorder.myPicks(st.settings).live, MY_LIVE_DEFAULT);
      t.eq(st.picks.length, 0, 'all keeper rounds are blank -> nothing pre-filled');
      t.eq(st.settings.keepers.length, 10, '10 keeper rows preloaded');
      t.ok(st.settings.keepers.every(k => k.round === null), 'all rounds blank');
      const shaheed = st.settings.keepers.find(k => k.team === 'Jeff');
      t.eq(shaheed.player, 'Rashid Shaheed', 'Jeff/Shaheed row exists, NOT kept');
      t.eq(NS.board.myTeamLabel(st.settings), 'KeiserSoze (Jeff)');
    });

    t.test('keeper add: Jim/Warren R8 -> pick 88 pre-filled + Warren off available; blanking restores both', () => {
      const st = fresh();
      addQ(st, 61, 'Tyler Warren', 'TE', 'IND');
      const row = st.settings.keepers.find(k => k.team === 'Jim');
      row.round = 8;
      ST.recompute(st);
      const { resolved } = NS.pickorder.resolveKeepers(st.settings);
      t.eq(resolved.length, 1);
      t.eq(resolved[0].pick, 88, 'Jim slot 9, R8 even -> pick 88');
      t.ok(st.picks.some(p => p.pick === 88 && p.keeper && p.player === 'Tyler Warren'), 'pre-filled');
      t.ok(!NS.board.available(st).some(p => p.normName === NS.normName('Tyler Warren')), 'off available');
      t.eq(st.picks[0].pos, 'TE', 'pos resolved from the queue');
      const tc = NS.board.teamCounts(st);
      t.eq(tc['Jim'].TE, 1, 'board counts include the keeper from pick 1');
      row.round = null;
      ST.recompute(st);
      t.ok(NS.board.available(st).some(p => p.normName === NS.normName('Tyler Warren')), 'back in available');
      t.ok(!st.picks.some(p => p.pick === 88), 'pick 88 back on the clock');
    });

    t.test('my-keeper (ME row): on my roster at pick 1, live picks drop by one, counts toward the build', () => {
      const st = fresh();
      addQ(st, 62, 'Rashid Shaheed', 'WR', 'NO');
      const row = st.settings.keepers.find(k => k.team === 'Jeff');
      // Blank round: none of the my-keeper behavior
      t.eq(NS.board.myRoster(st).length, 0, 'blank round -> not on roster');
      t.eq(NS.pickorder.myPicks(st.settings).live.length, 16);
      row.round = 4;
      ST.recompute(st);
      const roster = NS.board.myRoster(st);
      t.eq(roster.length, 1, 'on my roster');
      t.eq(roster[0].player, 'Rashid Shaheed');
      t.ok(roster[0].byMe && roster[0].keeper, 'flagged as my keeper');
      t.eq(roster[0].pick, 45, 'Jeff slot 4, R4 even -> pick 45');
      t.eq(NS.pickorder.myPicks(st.settings).live.length, 15, 'live picks drop by one');
      t.ok(!NS.pickorder.myPicks(st.settings).live.includes(45), 'round 4 pick consumed');
      t.eq(NS.board.posCounts(roster).WR, 1, 'counts toward the target build');
      const g = NS.buildpath.guard(st);
      t.eq(g.targets.WR - g.counts.WR, st.settings.targets.WR - 1, 'build guard sees the keeper WR');
      row.round = null;
      ST.recompute(st);
      t.eq(NS.board.myRoster(st).length, 0, 'blank again -> gone from roster');
      t.eq(NS.pickorder.myPicks(st.settings).live.length, 16);
    });

    t.test('two keepers on one team work; unmatched team name -> badge list, order not corrupted', () => {
      const st = fresh();
      st.settings.keepers.push({ team: 'Jim', player: 'Second Guy', round: 12 });
      st.settings.keepers.find(k => k.team === 'Jim' && k.player === 'Tyler Warren').round = 8;
      st.settings.keepers.push({ team: 'Nobody', player: 'Ghost Player', round: 3 });
      ST.recompute(st);
      const { resolved, unmatched } = NS.pickorder.resolveKeepers(st.settings);
      t.eq(resolved.length, 2, 'both Jim keepers resolved');
      t.eq(unmatched.length, 1, 'unmatched row reported');
      t.eq(unmatched[0].team, 'Nobody');
      const order = NS.pickorder.buildOrder(st.settings);
      t.eq(order.length, 192, 'order not corrupted');
      t.eq(order.filter(o => o.keeper).length, 2, 'unmatched keeper excluded from the board');
    });

    t.test('rule 5: rec card returns 5 legal names when 5 exist; fewer only when fewer are legal', () => {
      let st = fresh();
      fill(st, 3, {});
      let rec = NS.recommend(st);
      t.eq(rec.pick, 4);
      t.ok(rec.myPick, 'pick 4 is mine');
      t.eq(rec.espnQueue.length, 5, 'five names');
      t.eq(new Set(rec.espnQueue).size, 5, 'deduped');
      t.eq(rec.alts.length, 4, 'Alt2-Alt5');
      t.eq(rec.espnQueue[0], rec.primary.player.name, 'primary first');

      st = fresh();
      st.myQueue = st.myQueue.filter(p => ['Jahmyr Gibbs', 'Puka Nacua', 'Jonathan Taylor'].includes(p.name));
      fill(st, 3, {});
      rec = NS.recommend(st);
      t.eq(rec.espnQueue.length, 3, 'only 3 legal -> 3 names');
    });

    t.test('rule 1: rounds 1-4 never a QB (even Allen atop the queue); TE only McBride/Bowers', () => {
      const st = fresh();
      const allen = findQ(st, 'Josh Allen');
      st.myQueue = [{ ...allen, rank: 0 }].concat(st.myQueue.filter(p => p !== allen));
      for (const pick of [4, 21, 28, 45]) { // my picks in rounds 1-4
        const rec = NS.recommend(st, { forPick: pick });
        t.ok(rec.primary && rec.primary.player.pos !== 'QB', `primary not QB at pick ${pick}`);
        (rec.alts || []).forEach(a => t.ok(a.player.pos !== 'QB', `alts not QB at pick ${pick}`));
      }
      const rec4 = NS.recommend(st, { forPick: 4 });
      const dnt = rec4.doNotTake.find(d => d.player.normName === 'josh allen');
      t.ok(dnt && dnt.ruleId === 'R1', 'Allen blocked with R1 in round 1');
      // TE gate: McBride legal, a filler TE is not
      const ctx = NS.playbook.buildCtx(st, 4);
      t.ok(NS.playbook.legality(st, ctx, findQ(st, 'Trey McBride')).legal, 'McBride legal in rounds 1-4');
      const fillerTE = st.myQueue.find(p => p.pos === 'TE' && p.filler);
      t.eq(NS.playbook.legality(st, ctx, fillerTE).ruleId, 'R1', 'other TE blocked in rounds 1-4');
    });

    t.test('rule 2: exception at my 5th live pick only, both conditions required; QB legal from 6th', () => {
      // Case A: all tier-1/2 skill gone, Allen (tier 2) available -> fires at pick 52
      let st = fresh();
      const t12skill = st.myQueue.filter(p => p.tier <= 2 && NS.SKILL.includes(p.pos)).map(p => p.name);
      const mine = { 4: 'Jahmyr Gibbs', 21: "Ja'Marr Chase", 28: 'Puka Nacua', 45: 'Jonathan Taylor' };
      fill(st, 51, { mine, others: t12skill.filter(n => !Object.values(mine).includes(n)) });
      let rec = NS.recommend(st);
      t.eq(rec.pick, 52, '5th live pick');
      t.eq(rec.primary.player.name, 'Josh Allen', 'elite QB a full tier above skill -> taken');
      t.ok(rec.primary.why.rules.includes('R2'), 'R2 cited');

      // Case B: tier-1 skill still there -> tier condition fails, no QB at 52
      st = fresh();
      fill(st, 51, { mine });
      rec = NS.recommend(st);
      t.ok(rec.primary.player.pos !== 'QB', 'no QB when skill of equal/better tier remains');
      const dnt = rec.doNotTake.find(d => d.player.normName === 'josh allen');
      t.ok(dnt && dnt.ruleId === 'R2', 'Allen blocked with R2');

      // Case C: a non-elite QB never qualifies in the window
      const ctx52 = NS.playbook.buildCtx(st, 52);
      t.eq(NS.playbook.legality(st, ctx52, findQ(st, 'Joe Burrow')).ruleId, 'R2', 'Burrow not in the window');

      // Case D: at the 4th live pick even a qualifying elite is blocked
      st = fresh();
      fill(st, 44, { mine: { 4: 'Jahmyr Gibbs', 21: "Ja'Marr Chase", 28: 'Puka Nacua' }, others: t12skill.filter(n => !['Jahmyr Gibbs', "Ja'Marr Chase", 'Puka Nacua'].includes(n)) });
      rec = NS.recommend(st);
      t.eq(rec.pick, 45);
      t.ok(rec.primary.player.pos !== 'QB', 'no QB at the 4th live pick');

      // Case E: from the 6th live pick a QB is legal without conditions
      st = fresh();
      fill(st, 68, { mine: { 4: 'Jahmyr Gibbs', 21: "Ja'Marr Chase", 28: 'Puka Nacua', 45: 'Jonathan Taylor', 52: 'James Cook' } });
      const ctx69 = NS.playbook.buildCtx(st, 69);
      t.ok(NS.playbook.legality(st, ctx69, findQ(st, 'Joe Burrow')).legal, 'any QB legal at the 6th live pick');
    });

    t.test('rule 4: K/DST only on my last two live picks under 14-, 16-, and 18-round settings', () => {
      for (const rounds of [14, 16, 18]) {
        const st = fresh();
        st.settings.rounds = rounds;
        ST.recompute(st);
        const live = NS.pickorder.myPicks(st.settings).live;
        const kdst = live.slice(-2);
        const someK = st.myQueue.find(p => p.pos === 'K');
        const someD = st.myQueue.find(p => p.pos === 'DST');
        for (const pick of live.filter(p => !kdst.includes(p))) {
          const ctx = NS.playbook.buildCtx(st, pick);
          t.eq(NS.playbook.legality(st, ctx, someK).ruleId, 'R4', `${rounds}rd: K blocked at pick ${pick}`);
          t.eq(NS.playbook.legality(st, ctx, someD).ruleId, 'R4', `${rounds}rd: DST blocked at pick ${pick}`);
        }
        const recLast = NS.recommend(st, { forPick: kdst[0] });
        t.ok(['K', 'DST'].includes(recLast.primary.player.pos), `${rounds}rd: K/DST recommended at pick ${kdst[0]}`);
        t.ok(recLast.primary.why.rules.includes('R4'), 'R4 cited');
        // never a second of the same
        const st2 = fresh();
        st2.settings.rounds = rounds;
        ST.recompute(st2);
        st2.picks.push({ pick: kdst[0], team: 'Jeff', player: someK.name, pos: 'K', normName: someK.normName, keeper: false, byMe: true });
        const otherK = st2.myQueue.filter(p => p.pos === 'K')[1];
        const ctxLast = NS.playbook.buildCtx(st2, kdst[1]);
        t.eq(NS.playbook.legality(st2, ctxLast, otherK).ruleId, 'R4', 'second K blocked');
        t.eq(NS.recommend(st2, { forPick: kdst[1] }).primary.player.pos, 'DST', 'the other one at the last pick');
      }
    });

    t.test('rules 3+8: 3rd QB only after pick 130 and never over a startable RB/WR', () => {
      const st = fresh();
      const burrow = findQ(st, 'Joe Burrow');
      st.picks.push({ pick: 4, team: 'Jeff', player: 'Josh Allen', pos: 'QB', normName: 'josh allen', keeper: false, byMe: true });
      st.picks.push({ pick: 21, team: 'Jeff', player: 'Dak Prescott', pos: 'QB', normName: 'dak prescott', keeper: false, byMe: true });
      let ctx = NS.playbook.buildCtx(st, 120);
      t.eq(NS.playbook.legality(st, ctx, burrow).ruleId, 'R3', 'QB3 blocked before pick 130');
      ctx = NS.playbook.buildCtx(st, 141);
      t.eq(NS.playbook.legality(st, ctx, burrow).ruleId, 'R8', 'after 130 still blocked while startable RB/WR remain');
      // Remove every startable RB/WR from the queue -> QB3 becomes legal after 130
      st.myQueue = st.myQueue.filter(p => !['RB', 'WR'].includes(p.pos));
      ctx = NS.playbook.buildCtx(st, 141);
      t.ok(NS.playbook.legality(st, ctx, burrow).legal, 'QB3 legal after 130 with no startable RB/WR left');
    });

    t.test('rule 3: second TE only when both TEs are top-6 in my queue', () => {
      const st = fresh();
      addQ(st, 61, 'MidTier TE X', 'TE', 'PIT');
      const mcbride = findQ(st, 'Trey McBride');
      st.picks.push({ pick: 28, team: 'Jeff', player: mcbride.name, pos: 'TE', normName: mcbride.normName, keeper: false, byMe: true });
      const top6TE = st.myQueue.filter(p => p.pos === 'TE').sort((a, b) => a.rank - b.rank).slice(0, 6).map(p => p.normName);
      const goodTE2 = st.myQueue.find(p => p.pos === 'TE' && p.normName !== mcbride.normName && top6TE.includes(p.normName));
      const ctx = NS.playbook.buildCtx(st, 100);
      t.ok(NS.playbook.legality(st, ctx, goodTE2).legal, 'top-6 TE2 legal');
      t.eq(NS.playbook.legality(st, ctx, findQ(st, 'MidTier TE X')).ruleId, 'R3', 'mid-tier TE2 blocked');
    });

    t.test('rule 6: marker handcuff gated before pick 100 unless the starter went in the last 2 picks', () => {
      const st = fresh();
      const cuff = addQ(st, 61, 'Cuff Guy', 'RB', 'CHI');
      cuff.handcuffOf = 'Some Starter';
      t.eq(NS.overlay.hardGate(st, 50, cuff).ruleId, 'R6', 'gated at 50');
      t.eq(NS.overlay.hardGate(st, 100, cuff), null, 'free at 100');
      st.picks.push({ pick: 48, team: 'Joe', player: 'Some Starter', pos: 'RB', normName: NS.normName('Some Starter'), keeper: false, byMe: false });
      t.eq(NS.overlay.hardGate(st, 50, cuff), null, 'unlocked - starter went in the last 2 picks');
    });

    t.test('rule 7 overlay: fade loses a valid tie (exact why-line); never across tiers or >6 ranks', () => {
      const mkTie = (priceRank, priceTier) => {
        const st = fresh();
        st.myQueue = [];
        addQ(st, 1, 'Josh Jacobs', 'RB', 'LV', 1);       // default FADE
        addQ(st, priceRank, 'Jadarian Price', 'RB', 'DAL', priceTier); // default TARGET
        fill(st, 3, {});
        return NS.recommend(st); // my pick 4, round 1, both RB legal
      };
      let rec = mkTie(2, 1);
      t.eq(rec.primary.player.name, 'Jadarian Price', 'fade loses the tie');
      t.eq(rec.primary.why.text, 'Upside overlay: Price over Jacobs (fade)', 'exact why-line');
      t.ok(rec.primary.why.rules.includes('R7'), 'R7 cited');
      rec = mkTie(2, 2);
      t.eq(rec.primary.player.name, 'Josh Jacobs', 'tier boundary blocks the overlay');
      rec = mkTie(8, 1);
      t.eq(rec.primary.player.name, 'Josh Jacobs', '7 ranks apart blocks the overlay');
    });

    t.test('rule 7 overlay: stands down when a playbook rule decided the pick (R2 exception)', () => {
      const st = fresh();
      const t12skill = st.myQueue.filter(p => p.tier <= 2 && NS.SKILL.includes(p.pos)).map(p => p.name);
      const mine = { 4: 'Jahmyr Gibbs', 21: "Ja'Marr Chase", 28: 'Puka Nacua', 45: 'Jonathan Taylor' };
      fill(st, 51, { mine, others: t12skill.filter(n => !Object.values(mine).includes(n)) });
      // Lamar (dual-threat, tier 3... actually tier 2 gone) - make a tie zone irrelevant:
      const rec = NS.recommend(st);
      t.eq(rec.primary.player.name, 'Josh Allen', 'R2 exception holds');
      t.ok(!rec.primary.why.text.includes('Upside overlay'), 'overlay stood down');
    });

    t.test('keeper strip beats a Target with no error (rule 7)', () => {
      const st = fresh();
      addQ(st, 61, 'Tee Higgins', 'WR', 'CIN'); // default TARGET
      st.settings.keepers.push({ team: 'Joe', player: 'Tee Higgins', round: 5 });
      ST.recompute(st);
      t.ok(!NS.board.available(st).some(p => p.normName === NS.normName('Tee Higgins')), 'stripped');
      const rec = NS.safeRecommend(st, { forPick: 4 });
      t.ok(!rec.engineError, 'no error');
    });

    t.test('storage isolation: espn:-prefixed keys only; Yahoo state invisible', () => {
      const storage = fakeStorage({
        'draftos_state_v2': '{"version":2,"settings":{"teams":[{"slot":1,"name":"Colby"}]},"myQueue":[],"picks":[]}',
        'draftos_autosave': '{}'
      });
      const loaded = ST.load(storage);
      t.ok(loaded.fresh, 'ESPN app boots fresh - Yahoo keys ignored');
      t.eq(loaded.state.settings.teams.length, 12, 'ESPN defaults, not Yahoo state');
      ST.save(loaded.state, storage);
      const newKeys = Object.keys(storage._data).filter(k => !['draftos_state_v2', 'draftos_autosave'].includes(k));
      t.ok(newKeys.length >= 1, 'wrote at least one key');
      t.ok(newKeys.every(k => k.startsWith('espn:')), `only espn:-prefixed keys written (${newKeys})`);
      t.eq(storage._data['draftos_state_v2'].includes('Colby'), true, 'Yahoo key untouched');
    });

    t.test('setup guard recompute: slot/order changes re-derive teams; keeper collision drops the live pick', () => {
      const st = fresh();
      fill(st, 3, {});
      pushPick(st, 4, findQ(st, 'Jahmyr Gibbs'), true);
      t.ok(st.picks.some(p => !p.keeper), 'a pick has been marked');
      st.settings.mySlot = 7; // I am now Dan
      ST.recompute(st);
      const p4 = st.picks.find(p => p.pick === 4);
      t.eq(p4.team, 'Jeff', 'pick 4 still belongs to slot 4 (Jeff)');
      t.ok(!p4.byMe, 'no longer mine after the slot change');
      t.eq(NS.board.currentPick(st), 5, 'board intact');
      // Keeper claiming a pick already marked live: keeper wins, live entry dropped
      st.settings.keepers.push({ team: 'Joe', player: 'Keeper Guy', round: 1 }); // Joe slot 1 -> pick 1
      ST.recompute(st);
      const p1 = st.picks.find(p => p.pick === 1);
      t.ok(p1.keeper && p1.player === 'Keeper Guy', 'keeper wins the collision');
      t.eq(st.picks.filter(p => p.pick === 1).length, 1, 'no duplicate pick entries');
    });

    t.test('catch-up paste walks the 12-team snake and skips keeper picks', () => {
      const st = fresh();
      st.settings.keepers.find(k => k.team === 'Rhett').round = 3; // slot 2, R3 odd -> pick 26
      ST.recompute(st);
      t.eq(NS.pickorder.resolveKeepers(st.settings).resolved[0].pick, 26);
      fill(st, 24, { mine: { 4: 'Jahmyr Gibbs', 21: "Ja'Marr Chase" } });
      t.eq(NS.board.currentPick(st), 25);
      const res = NS.board.assignCatchup(st, NS.parser.parseCatchup('Derrick Henry, George Pickens, Nico Collins'));
      t.eq(res.unmatched.length, 0);
      t.eq(res.assignments.map(a => [a.pick, a.team]), [[25, 'Joe'], [27, 'Mike'], [28, 'Jeff']], 'keeper pick 26 skipped; 28 is mine');
      t.ok(res.assignments[2].byMe, 'pick 28 flagged as mine');
    });

    t.test("name normalization: Ja'Marr Chase variants all match; bye table wins over pasted bye", () => {
      const st = fresh();
      for (const variant of ["Ja'Marr Chase", 'JaMarr Chase', "Chase, Ja'Marr", 'JAMARR CHASE']) {
        const m = NS.matchName(variant, st.myQueue);
        t.ok(m.kind === 'exact' && m.player.name === "Ja'Marr Chase", `variant "${variant}"`);
      }
      const parsed = NS.parser.parseQueue('1. James Cook RB BUF 9', { byes: st.settings.byes, keepers: [], tierSize: 12 });
      t.eq(parsed.players[0].bye, 7, 'table bye (BUF=7) wins');
      t.ok(parsed.players[0].tags.includes('bye mismatch'), 'bye mismatch badge');
    });

    t.test('sample queue: tiers 1/2/3 parse; filler removed on a real paste; kept players stay hidden', () => {
      const st = fresh();
      t.eq(findQ(st, 'Jahmyr Gibbs').tier, 1);
      t.eq(findQ(st, 'Josh Allen').tier, 2);
      t.eq(findQ(st, 'Derrick Henry').tier, 3);
      t.ok(st.myQueue.some(p => p.filler), 'fillers present');
      const paste = Array.from({ length: 20 }, (_, i) => `${i + 1}. Real Player ${i + 1} WR DET 6`).join('\n');
      const parsed = NS.parser.parseQueue(paste, { byes: st.settings.byes, keepers: [], tierSize: 12 });
      st.myQueue = parsed.players; st.usingSample = false;
      t.eq(st.myQueue.length, 20, 'paste replaces the whole queue');
      t.ok(!st.myQueue.some(p => p.filler), 'fillers gone');
      // an active keeper pasted back stays hidden from available
      st.settings.keepers.find(k => k.team === 'Joe').round = 2;
      addQ(st, 21, 'Tyjae Spears', 'RB', 'TEN');
      ST.recompute(st);
      t.ok(!NS.board.available(st).some(p => p.normName === NS.normName('Tyjae Spears')), 'kept player hidden after paste');
    });

    t.test('undo restores exact prior state; storage round-trips full state', () => {
      const st = fresh();
      const before = JSON.stringify({ picks: st.picks, log: st.log });
      ST.snapshot(st);
      pushPick(st, 1, findQ(st, 'Jahmyr Gibbs'), false);
      st.log.push({ t: 'pick', msg: 'x' });
      t.ok(ST.undo(st), 'undo ran');
      t.eq(JSON.stringify({ picks: st.picks, log: st.log }), before, 'exact prior state');
      const storage = fakeStorage();
      pushPick(st, 1, findQ(st, 'Jahmyr Gibbs'), false);
      ST.save(st, storage);
      const loaded = ST.load(storage);
      t.ok(!loaded.corrupt);
      t.eq(JSON.stringify(ST.exportable(loaded.state)), JSON.stringify(ST.exportable(st)), 'round-trip');
    });

    t.test('Monte Carlo: protected player survives at 100%; ADP-1 unprotected is essentially gone', () => {
      const st = fresh();
      fill(st, 4, { mine: { 4: 'Jonathan Taylor' } });
      NS.survival.clearCache();
      const mc1 = NS.survival.monteCarlo(st, { protect: ['Jahmyr Gibbs'], n: 50, seed: 42, budgetMs: 5000, force: true });
      t.eq(mc1.targetPick, 21, 'sim to my next live pick');
      t.eq(mc1.probs['jahmyr gibbs'], 100, 'protected -> 100%');
      st.adp = NS.parser.parseRankList('1. Jahmyr Gibbs\n2. Puka Nacua\n3. Christian McCaffrey', {});
      const mc2 = NS.survival.monteCarlo(st, { protect: [], n: 50, seed: 42, budgetMs: 5000, force: true });
      t.ok(mc2.probs['jahmyr gibbs'] < 5, `ADP-1 unprotected -> <5% (got ${mc2.probs['jahmyr gibbs']}%)`);
      NS.survival.clearCache();
    });

    t.test('build-path guard: 3rd QB dropped first when the build no longer fits', () => {
      const st = fresh();
      st.settings.targets = { QB: 3, RB: 6, WR: 6, TE: 2, K: 1, DST: 1 }; // 19 slots
      fill(st, 51, { mine: { 4: 'Jahmyr Gibbs', 21: 'Jonathan Taylor', 28: "Ja'Marr Chase", 45: 'Puka Nacua' } });
      const g = NS.buildpath.guard(st);
      t.eq(g.picksLeft, 12, '12 live picks left from pick 52');
      t.ok(g.dropped.length >= 1, 'targets relaxed');
      t.eq(g.dropped[0], '3rd QB', '3rd QB dropped first');
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
        settings: { teams: st.settings.teams, mySlot: 4, rounds: 16, keepers: st.settings.keepers, byes: st.settings.byes, clockSeconds: 75 },
        myQueue: st.myQueue.slice(0, 10),
        picks: [],
        log: [{ t: 'init', msg: 'old' }]
      };
      const migrated = ST.migrate(JSON.parse(JSON.stringify(v1)));
      t.eq(migrated.version, 2);
      t.eq(migrated.settings.clockSeconds, 75, 'user setting preserved');
      t.eq(migrated.myQueue.length, 10, 'queue preserved');
      t.ok(migrated.settings.flags && migrated.settings.simQB.firstQBStart === 4, 'v2 fields added');
    });

    t.test('ESPN pre-draft list: queue order, active keepers stripped, K/DST at the bottom', () => {
      const st = fresh();
      addQ(st, 61, 'Tyler Warren', 'TE', 'IND');
      st.settings.keepers.find(k => k.team === 'Jim').round = 8;
      ST.recompute(st);
      const lines = ST.espnPreDraftList(st).split('\n');
      t.ok(!lines.includes('Tyler Warren'), 'active keeper stripped');
      t.eq(lines[0], 'Jahmyr Gibbs', 'queue order preserved');
      const kdstCount = st.myQueue.filter(p => ['K', 'DST'].includes(p.pos)).length;
      const tail = lines.slice(-kdstCount);
      t.ok(tail.every(n => /Filler (K|DST)/.test(n)), 'K/DST at the bottom');
    });

    return t.results;
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
