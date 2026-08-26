// League facts. Everything here is a DEFAULT — Settings can edit teams,
// keepers, byes, thresholds. Nothing is fetched from the network, ever.
(function () {
  const NS = globalThis.DraftOS;

  NS.DATA = {};

  NS.DATA.TEAMS = [
    { slot: 1, name: 'Colby' },
    { slot: 2, name: 'Mike' },
    { slot: 3, name: 'Chris' },
    { slot: 4, name: 'Rob' },
    { slot: 5, name: 'Andrew' },
    { slot: 6, name: 'Hugo' },
    { slot: 7, name: 'Jeff K' },
    { slot: 8, name: 'Nolan' },
    { slot: 9, name: 'Bibhor' },
    { slot: 10, name: 'Oskar' }
  ];

  NS.DATA.MY_SLOT = 7;
  NS.DATA.ROUNDS = 19;
  NS.DATA.TEAM_COUNT = 10;

  // Keeper pick numbers are re-derived from the snake formula and asserted
  // against these values in the tests.
  NS.DATA.KEEPERS = [
    { team: 'Andrew', player: 'Bijan Robinson', pos: 'RB', nfl: 'ATL', round: 1, pick: 5 },
    { team: 'Jeff K', player: 'Josh Allen', pos: 'QB', nfl: 'BUF', round: 3, pick: 27 },
    { team: 'Nolan', player: 'Brock Bowers', pos: 'TE', nfl: 'LV', round: 3, pick: 28 },
    { team: 'Hugo', player: 'Jaxon Smith-Njigba', pos: 'WR', nfl: 'SEA', round: 4, pick: 35 },
    { team: 'Oskar', player: 'Drake Maye', pos: 'QB', nfl: 'NE', round: 6, pick: 51 },
    { team: 'Colby', player: 'Jayden Daniels', pos: 'QB', nfl: 'WAS', round: 8, pick: 80 },
    { team: 'Bibhor', player: 'Rashee Rice', pos: 'WR', nfl: 'KC', round: 10, pick: 92 },
    { team: 'Chris', player: 'Colston Loveland', pos: 'TE', nfl: 'CHI', round: 15, pick: 143 },
    { team: 'Rob', player: 'Quinshon Judkins', pos: 'RB', nfl: 'CLE', round: 16, pick: 157 },
    { team: 'Mike', player: 'Luther Burden III', pos: 'WR', nfl: 'CHI', round: 16, pick: 159 }
  ];

  // 2026 team bye weeks. The table always wins over a pasted bye column.
  NS.DATA.BYES = {
    ARI: 14, ATL: 11, BAL: 13, BUF: 7, CAR: 5, CHI: 10, CIN: 6, CLE: 11,
    DAL: 14, DEN: 10, DET: 6, GB: 11, HOU: 8, IND: 13, JAX: 7, KC: 5,
    LAC: 7, LAR: 11, LV: 13, MIA: 6, MIN: 6, NE: 11, NO: 8, NYG: 8,
    NYJ: 13, PHI: 10, PIT: 9, SEA: 11, SF: 8, TB: 10, TEN: 9, WAS: 7
  };

  NS.DATA.QB2_POOL = [
    'Dak Prescott', 'Trevor Lawrence', 'Jaxson Dart', 'Patrick Mahomes',
    'Bo Nix', 'Brock Purdy', 'Justin Herbert'
  ];

  NS.DATA.IR_LATE = ['Jordyn Tyson', 'Zach Charbonnet', 'Alvin Kamara'];       // pick 147+
  NS.DATA.IR_SEASON_END = ['Jayden Higgins', 'Ricky Pearsall'];                // pick 187 only

  NS.DATA.INJURY_TAGS = [
    { name: 'Josh Allen', tag: 'bye 7' },
    { name: 'Justin Herbert', tag: 'bye 7' },
    { name: "Ja'Marr Chase", tag: 'knee (monitor)' },
    { name: 'Christian McCaffrey', tag: 'load-manage' },
    { name: 'Malik Nabers', tag: 'ACL rehab' },
    { name: 'Kenneth Walker', tag: 'foot' },
    { name: 'Ashton Jeanty', tag: 'ankle' },
    { name: 'Patrick Mahomes', tag: 'ACL return' },
    { name: 'Zach Charbonnet', tag: 'PUP / Price SEA lead back' },
    { name: 'Jordyn Tyson', tag: 'hamstring IR-likely' },
    { name: 'Alec Pierce', tag: 'ankle/PUP' },
    { name: 'George Kittle', tag: 'Achilles' },
    { name: 'Jordan Love', tag: 'ankle' }
  ];

  NS.DATA.SCORING_TEXT =
    '6-pt pass TD - 6-pt rush/rec TD - 1 PPR - +3 for a 40+ yd completion - ' +
    '+3 for a 40+ yd reception - DST points-allowed tiers - FG 3/4/5 by distance - PAT 1. ' +
    '(Reference only - this app has no points engine.)';

  NS.DATA.SAMPLE_QUEUE_TEXT = [
    'TIER 1',
    '1. Jahmyr Gibbs RB DET 6',
    "2. Ja'Marr Chase WR CIN 6",
    '3. Puka Nacua WR LAR 11',
    '4. Christian McCaffrey RB SF 8',
    '5. Jonathan Taylor RB IND 13',
    '6. Amon-Ra St. Brown WR DET 6',
    '7. James Cook RB BUF 7',
    '8. CeeDee Lamb WR DAL 14',
    'TIER 2',
    '9. Lamar Jackson QB BAL 13',
    '10. Justin Jefferson WR MIN 6',
    "11. De'Von Achane RB MIA 6",
    '12. Drake London WR ATL 11',
    '13. Chase Brown RB CIN 6',
    '14. Omarion Hampton RB LAC 7',
    '15. Trey McBride TE ARI 14',
    '16. Saquon Barkley RB PHI 10',
    '17. A.J. Brown WR NE 11',
    '18. Nico Collins WR HOU 8',
    '19. Ashton Jeanty RB LV 13',
    '20. George Pickens WR DAL 14',
    'TIER 3',
    '21. Derrick Henry RB BAL 13',
    '22. Jalen Hurts QB PHI 10',
    '23. Joe Burrow QB CIN 6',
    '24. Caleb Williams QB CHI 10',
    '25. Dak Prescott QB DAL 14'
  ].join('\n');

  // Filler rows extend the sample so a mock draft can reach pick 34+.
  // Removed automatically the moment a real queue is pasted (paste replaces all).
  NS.DATA.buildFillers = function () {
    const teams = Object.keys(NS.DATA.BYES);
    const cycle = ['RB', 'WR', 'WR', 'RB', 'TE', 'QB'];
    const out = [];
    for (let rank = 26; rank <= 60; rank++) {
      let pos;
      if (rank === 55 || rank === 57) pos = 'K';
      else if (rank === 56 || rank === 58) pos = 'DST';
      else pos = cycle[(rank - 26) % cycle.length];
      const team = teams[(rank - 26) % teams.length];
      out.push({
        rank, name: `Filler ${pos} ${rank}`, pos, team,
        bye: NS.DATA.BYES[team], tier: 3 + Math.ceil((rank - 25) / 12),
        tags: ['filler'], filler: true
      });
    }
    return out;
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = NS;
})();
