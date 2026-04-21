#!/usr/bin/env python3
"""
Pure exit-decision logic — no API calls, no globals.
Imported by openclaw.py and tested independently in tests/test_cashout.py.
"""

CASHOUT_ADVERSE = 0.12   # tightened from 0.20 — exit before position is nearly worthless
CASHOUT_MINUTES = 2      # minimum age before cashout is eligible
PROFITLOCK_MIN_AGE = 3.0 # minutes before ProfitLock can fire — prevents noise exits


def sell_side_for_direction(direction):
    """YES contracts (UP trades) are sold as 'yes'; NO contracts (DOWN) as 'no'."""
    return "yes" if direction == "UP" else "no"


def compute_win_prob(direction, cur_yes):
    """Current probability that this position wins at expiry."""
    return cur_yes if direction == "UP" else (1 - cur_yes)


def compute_adverse(direction, cur_yes, entry_yes):
    """
    How far has the market moved against us since entry (positive = bad).

    UP  trade: adverse when YES drops  → entry_yes - cur_yes
    DOWN trade: adverse when YES rises → cur_yes - (1 - entry_yes)
    """
    if direction == "UP":
        return entry_yes - cur_yes
    else:
        return cur_yes - (1 - entry_yes)


def compute_sell_value(contracts, direction, cur_yes):
    """Dollar value received from selling this position at the current market price."""
    price = cur_yes if direction == "UP" else (1 - cur_yes)
    return round(contracts * price, 2)


def compute_profitlock_win_floor(entry_win_prob):
    """
    ProfitLock fires when win_prob has dropped BELOW this floor.

    High-confidence entries (>= 0.85) require larger degradation before exiting —
    they have more room to absorb noise. Floors are set so that the false positives
    observed at win_prob=0.75-0.81 on strong-conviction entries no longer trigger.
    """
    if entry_win_prob >= 0.85:
        return 0.72   # must degrade from 0.87+ down to below 0.72
    elif entry_win_prob >= 0.70:
        return 0.65   # must degrade from 0.70-0.85 down to below 0.65
    else:
        return 0.55   # low-conviction entries exit earlier


def compute_reversal_threshold(entry_win_prob):
    """
    How far price must reverse from peak before ProfitLock is eligible.

    High-confidence entries need a larger reversal (0.15) to filter out
    noise at extreme YES prices (e.g. 0.10 bouncing to 0.19 is normal).
    """
    return 0.15 if entry_win_prob >= 0.85 else 0.08


def compute_cashout_win_floor(entry_win_prob):
    """
    CashOut only fires when win_prob is AT OR BELOW this floor.

    Simulation of 390 trades (Mar-Apr 2026) at T=0.12 showed 97% false-positive
    rate: 97 winning positions exited vs 3 actual losses caught. Losses in this
    system are rapid collapses (yes→0 in 1-2 cycles), not gradual drift that
    CashOut can intercept. Setting floor=0.50 for directional entries confines
    CashOut to positions that have genuinely crossed to losing territory.
    The BreakEven layer (win_prob<0.45, age>=2.5) provides the primary safety net.
    """
    if entry_win_prob >= 0.60:
        return 0.50   # directional entries: only exit when market says <50% chance of winning
    else:
        return 0.0    # low-confidence entries: preserve adverse-only logic


def compute_exit_reason(direction, cur_yes, entry_yes, age_placed, status,
                        cashout_adverse=CASHOUT_ADVERSE,
                        cashout_minutes=CASHOUT_MINUTES,
                        peak_yes=None,
                        profitlock_hold_mins=PROFITLOCK_MIN_AGE):
    """
    Determine whether to exit a position and the reason.

    Returns (reason_str, exit_type) or (None, None) to hold.
    exit_type: 'hard_floor' | 'profit_lock' | 'break_even' | 'cashout' | None

    Priority order (highest first):
      1. hard_floor  — price at extreme limit, almost nothing left to salvage
      2. profit_lock — position was winning but has degraded past the lock floor
      3. break_even  — high-conviction entry that has crossed to the losing side
      4. cashout     — adverse move exceeded threshold
    """
    if status not in ("open", "active"):
        return None, None
    if direction not in ("UP", "DOWN"):
        return None, None

    win_prob = compute_win_prob(direction, cur_yes)
    entry_win = entry_yes if direction == "UP" else (1 - entry_yes)
    adverse = compute_adverse(direction, cur_yes, entry_yes)
    hard_floor = (direction == "UP" and cur_yes < 0.06) or (direction == "DOWN" and cur_yes > 0.94)

    # Dynamic reversal threshold — larger buffer for high-confidence entries
    rev_thresh = compute_reversal_threshold(entry_win)
    peak = peak_yes if peak_yes is not None else entry_yes
    if direction == "UP":
        reversal = (peak - cur_yes) > rev_thresh
    else:
        reversal = (cur_yes - peak) > rev_thresh

    # Dynamic ProfitLock floor — only exit when win_prob has degraded enough
    pl_floor = compute_profitlock_win_floor(entry_win)

    # Tighten adverse threshold in the final 3 minutes of the window
    late_thresh = 0.05 if age_placed >= 12 else cashout_adverse

    if hard_floor and age_placed >= 0.5:
        return f"HardFloor YES={cur_yes:.2f}", "hard_floor"
    if pl_floor > win_prob > 0.45 and reversal and age_placed >= profitlock_hold_mins:
        return f"ProfitLock win={win_prob:.2f}", "profit_lock"
    if win_prob < 0.45 and age_placed >= 2.5 and entry_win > 0.60:
        return f"BreakEven {win_prob:.0%}", "break_even"
    cashout_floor = compute_cashout_win_floor(entry_win)
    cashout_allowed = win_prob <= cashout_floor if cashout_floor > 0.0 else True
    if adverse > late_thresh and age_placed >= cashout_minutes and cashout_allowed:
        return f"CashOut adverse={adverse:.2f}", "cashout"
    return None, None
