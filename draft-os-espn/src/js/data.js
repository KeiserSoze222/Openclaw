// ESPN 12-team 1QB league facts. Everything here is a DEFAULT - Settings and
// the Keepers tab can edit teams, slot, rounds, keepers. No network, ever.
(function () {
  const NS = globalThis.DraftOS;

  NS.DATA = {};

  // Draft order is UNKNOWN at boot: these names are the league's managers in
  // a placeholder order, typed into the real order right before the draft.
  // "Jeff" is me (team label: KeiserSoze).
  NS.DATA.TEAMS = [
    { slot: 1, name: 'Joe' },
    { slot: 2, name: 'Rhett' },
    { slot: 3, name: 'Mike' },
    { slot: 4, name: 'Jeff' },
    { slot: 5, name: 'TC' },
    { slot: 6, name: 'Max' },
    { slot: 7, name: 'Dan' },
    { slot: 8, name: 'Pat' },
    { slot: 9, name: 'Jim' },
    { slot: 10, name: 'Ger' },
    { slot: 11, name: 'Team 11' },
    { slot: 12, name: 'Team 12' }
  ];

  NS.DATA.MY_SLOT = 4;           // where "Jeff" sits in the placeholder order
  NS.DATA.MY_LABEL = 'KeiserSoze (Jeff)';
  NS.DATA.ROUNDS = 16;           // editable 14-18
  NS.DATA.ROUNDS_MIN = 14;
  NS.DATA.ROUNDS_MAX = 18;
  NS.DATA.TEAM_COUNT = 12;

  // Keepers are stored by TEAM NAME with a round; a BLANK round = not kept
  // (the player stays in the queue). Pick numbers are resolved only once
  // slot + draft order are saved. All rows pre-load with blank rounds -
  // including Jeff/Shaheed (NOT keeping him unless a round is typed).
  NS.DATA.KEEPERS = [
    { team: 'Joe', player: 'Tyjae Spears', round: null },
    { team: 'Rhett', player: 'Marvin Mims Jr.', round: null },
    { team: 'Mike', player: 'Elic Ayomanor', round: null },
    { team: 'Jeff', player: 'Rashid Shaheed', round: null },
    { team: 'TC', player: 'Bhayshul Tuten', round: null },
    { team: 'Max', player: 'Trey Benson', round: null },
    { team: 'Dan', player: 'Michael Penix Jr.', round: null },
    { team: 'Pat', player: 'Quinshon Judkins', round: null },
    { team: 'Jim', player: 'Tyler Warren', round: null },
    { team: 'Ger', player: 'Luther Burden III', round: null }
  ];

  // 2026 team bye weeks - carried over unchanged. Table wins over pasted byes.
  NS.DATA.BYES = {
    ARI: 14, ATL: 11, BAL: 13, BUF: 7, CAR: 5, CHI: 10, CIN: 6, CLE: 11,
    DAL: 14, DEN: 10, DET: 6, GB: 11, HOU: 8, IND: 13, JAX: 7, KC: 5,
    LAC: 7, LAR: 11, LV: 13, MIA: 6, MIN: 6, NE: 11, NO: 8, NYG: 8,
    NYJ: 13, PHI: 10, PIT: 9, SEA: 11, SF: 8, TB: 10, TEN: 9, WAS: 7
  };

  // Rule 2 exception window (my 5th live pick only) and rule-1 early TEs.
  NS.DATA.ELITE_QBS = ['Josh Allen', 'Lamar Jackson', 'Jalen Hurts'];
  NS.DATA.EARLY_TES = ['Trey McBride', 'Brock Bowers'];

  NS.DATA.INJURY_TAGS = [
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
    'Half-PPR - 6-pt pass TD - 0.1/completion - -3 INT - +1 for 300-399 pass yds, ' +
    '+3 for 400+ - 0.1 per rush/rec yd - +1 for 100-199 rush or rec yds, +3 for 200+ - ' +
    'FG 3/3/5/6 - DST points-allowed and yards-allowed tiers. ' +
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
    '9. Justin Jefferson WR MIN 6',
    "10. De'Von Achane RB MIA 6",
    '11. Drake London WR ATL 11',
    '12. Chase Brown RB CIN 6',
    '13. Omarion Hampton RB LAC 7',
    '14. Trey McBride TE ARI 14',
    '15. Saquon Barkley RB PHI 10',
    '16. A.J. Brown WR NE 11',
    '17. Nico Collins WR HOU 8',
    '18. Ashton Jeanty RB LV 13',
    '19. George Pickens WR DAL 14',
    '20. Josh Allen QB BUF 7',
    'TIER 3',
    '21. Derrick Henry RB BAL 13',
    '22. Lamar Jackson QB BAL 13',
    '23. Jalen Hurts QB PHI 10',
    '24. Joe Burrow QB CIN 6',
    '25. Dak Prescott QB DAL 14'
  ].join('\n');

  // Filler rows so a mock can run deep before the real queue is pasted.
  // Removed when a real queue is pasted (paste replaces all).
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
