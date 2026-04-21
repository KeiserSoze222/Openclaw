# Arena Realism Audit
**File analyzed:** `/home/user/Openclaw/arena.py` (1,062 lines)  
**Analysis date:** April 21, 2026

---

## What Arena Does

Arena is a paper-trading genetic algorithm engine. It:
1. Reads live market signals from `arena_signal_{btc,eth,sol}.json` (written by real bots)
2. Evaluates 12 genome variants against those signals
3. Simulates trade outcomes using `random.random()`
4. Mutates poorly/well-performing variants
5. Optionally promotes the best variant to replace `openclaw.py`

---

## Task 2.1 — Fee Modeling

**Status: Partial approximation — not accurate**

Arena uses: `bet*0.85 if win else -bet`

This hardcodes a **15% fee** on wins. Real Kalshi structure:
- Per-contract fee: ~$0.03/contract per side (entry + exit)  
- On a $10 bet at YES=0.75 = 13 contracts: fee = 13×$0.03×2 = $0.78 = **7.8%**
- On a $10 bet at YES=0.90 = 11 contracts: fee = 11×$0.03×2 = $0.66 = **6.6%**

The Arena 15% fee **overstates costs by ~2×**, making variants appear less profitable than they are. This inflates the number of mutations toward "lower threshold" to compensate, distorting evolution.

**Fix:** Use `bet*(1/entry_yes - fee_rate) if win else -bet` with `fee_rate=0.06`.

---

## Task 2.2 — Slippage Modeling

**Status: Not modeled**

Arena's `place_order()` uses `contract_count=max(1,int(bet/0.50))` regardless of market price — it hardcodes YES=0.50 for contract sizing. The real bot uses actual market price.

The `yes_price` and `no_price` parameters add 2¢ to market price (Arena) vs 5¢ (live bot). Neither accounts for orderbook depth or actual fill prices.

**Impact:** Arena consistently underestimates contract count at extreme prices (YES=0.85 → Arena: 20 contracts, real: 11 contracts). This means Arena's P&L numbers are not comparable to real bot P&L.

---

## Task 2.3 — IOC Fill Rejection Simulation

**Status: Not simulated**

Arena's `place_order()` is in `DRY_RUN=True` mode (line 55). When `DRY_RUN=True`, orders are immediately logged as filled — no API call made, no IOC rejection possible.

The real fill rate is **70%** (measured from bot logs). Arena assumes **100% fill rate**, overstating trade frequency by ~43%.

---

## Task 2.4 — Cashout System

**Status: Not applied to paper trades**

Arena has its own `check_open_positions()` function (lines 630–854). However since `DRY_RUN=True`, positions are never actually placed, so there is nothing to monitor or exit.

Additionally, Arena's cashout logic contains a **critical bug**: on line 673:
```python
sell_side = "no" if direction=="UP" else "yes"
```
This is **wrong** — UP positions (YES contracts) must be sold as `"yes"`, not `"no"`. This is the same bug that was already fixed in `openclaw.py` but never propagated to `arena.py`.

Arena also does not import `compute_exit_reason()` from `exit_logic.py` — it reimplements exit logic independently and does not benefit from the April 20-21 cashout floor fix.

---

## Task 2.5 — Session Halts and Circuit Breakers

**Status: Present but based on simulated balance**

Arena's `safety_check()` (lines 281–295) checks:
- Balance < `MIN_BALANCE` ($120) — uses simulated `CURRENT_BALANCE`, not real
- Daily loss > 12% — against simulated session start
- Circuit breaker at WR < 45% over 10+ trades

The real balance is fetched by `get_live_balance()` but only at `safety_check()` time. Arena's `CURRENT_BALANCE` starts at `INITIAL_BALANCE=200.29` and updates based on simulated wins/losses, not real fills.

This means Arena can halt if simulated balance falls below $120 even when real balance is fine, or continue running when real balance has declined.

---

## Task 2.6 — Orderbook Liquidity Check

**Status: Not checked**

Arena's `place_order()` does not call `get_orderbook_liquidity()`. Since `DRY_RUN=True`, all paper trades assume unlimited liquidity at the quoted price.

---

## Task 2.7 — Variant Independence

**Status: NOT independent — all variants evaluate identical signals**

All 12 variants read from the same 3 files:
```
/root/arena_signal_btc.json
/root/arena_signal_eth.json
/root/arena_signal_sol.json
```

These files contain a single `yes_prob` value written once per cycle by the live bot. When multiple variants are assigned to the same market (e.g., v001, v004, v005, v011, v012 are all `btc`), they all see the exact same `yes_prob` at the same moment.

**Variant parameters:**

| ID | Market | Threshold | Bet% | MinConf | ChopAllowed |
|----|--------|-----------|------|---------|-------------|
| v001 | btc | 0.70 | 7% | 6 | ✗ |
| v002 | btc | 0.65 | 9% | 5 | ✗ |
| v003 | btc | 0.75 | 5% | 7 | ✗ |
| v004 | btc | 0.68 | 7% | 6 | ✗ |
| v005 | btc | 0.70 | 7% | 6 | ✗ |
| v006 | eth | 0.70 | 9% | 6 | ✗ |
| v007 | eth | 0.65 | 11% | 5 | ✗ |
| v008 | eth | 0.75 | 7% | 7 | ✗ |
| v009 | sol | 0.70 | 5% | 6 | ✗ |
| v010 | sol | 0.65 | 7% | 5 | ✗ |
| v011 | btc | 0.70 | 7% | 6 | ✗ |
| v012 | btc | 0.70 | 7% | 6 | ✗ |

Note: v001, v005, v011, v012 have **identical parameters** — they will always produce statistically identical results, just with different random seeds.

The performance differences between variants are **pure random variance**, not evidence of parameter quality. No meaningful conclusion can be drawn from the Arena leaderboard.

---

## Task 2.8 — Why No Variants Have Evolved Past Generation 1

**The genetic algorithm is effectively frozen.**

The `evaluate()` function (lines 957–976) only mutates a variant when:
1. `trades >= 50` (minimum sample), AND either:
2. `WR < 0.35` (fire sale: tighten threshold), OR
3. `WR > 0.92 AND trades % 100 == 0`

**The problem:** Since Arena simulates outcomes using `random.random() < market_yes_prob`, variants converge to WR ≈ 84-89% (reflecting the actual market probability distribution). This is between 0.35 and 0.92 — the dead zone where no mutation is triggered.

For condition 3 to fire: a variant needs WR > 92% sustained long enough to hit a multiple of 100 trades. Given that the live bot's actual WR is 84-93%, this requires extended luck that never materializes.

**Additional issue:** Even when condition 3 triggers, mutations are cosmetic:
- `lower_threshold`: reduces entry_threshold by 0.02 (minimal signal impact)
- `higher_bet`: increases max_bet_pct by 0.01 (minimal capital impact)

No mutation modifies `min_confidence`, `chop_allowed`, `news_weight`, exit logic parameters, or TOD schedules — the parameters with the largest actual impact on performance.

---

## AutoPromote Bug (Fixed)

The `OPENCLAW_FILE` path was set to `/home/user/Openclaw/openclaw.py` (dev environment).  
**Fixed to:** `/root/openclaw.py`

This caused a `FileNotFoundError` every Arena cycle. Even after the fix, AutoPromote should remain disabled until Arena simulation is validated — the 70% fill rate and random-outcome simulation make Arena results unreliable for promotion decisions.

---

## Summary — What Arena Provides vs What It Should

| Capability | Arena Actual | Arena Should |
|-----------|-------------|--------------|
| Real outcomes | ❌ `random.random()` | ✅ Real settlement |
| Fee accuracy | ⚠️ 15% hardcoded | ✅ Contract-level fee |
| Slippage | ❌ None | ✅ Orderbook-based |
| IOC rejections | ❌ None | ✅ 30% rejection rate |
| Cashout logic | ❌ Broken sell_side bug | ✅ `exit_logic.py` |
| Balance tracking | ⚠️ Simulated | ✅ Real API |
| Liquidity check | ❌ None | ✅ Depth check |
| Variant independence | ❌ Shared signal | ✅ Unique signal per variant |

---

## Recommendations

1. **Do not trust Arena leaderboard** for promotion decisions until simulation quality is fixed.
2. **Short-term fix:** Use real settlement results instead of `random.random()` by querying the fills API after each position expires.
3. **Fix sell_side bug** in arena's `check_open_positions()`: `"yes" if direction=="UP" else "no"`.
4. **Fix fee calculation:** Replace `bet*0.85` with contract-level fee model.
5. **Track fill rejection rate** per variant — 30% rejection means 30% of variant "trades" never actually execute.
6. **Expand mutation space** to include `min_confidence`, `chop_allowed`, and `cashout_adverse` parameters.
7. **Keep AutoPromote disabled** until Arena can demonstrate validated performance on real outcomes over ≥200 real trades.
