#!/usr/bin/env python3
"""
Pure exit-decision logic — no API calls, no globals.
Imported by openclaw.py and tested independently in tests/test_cashout.py.
"""

CASHOUT_ADVERSE = 0.12   # tightened from 0.20 — exit before position is nearly worthless
CASHOUT_MINUTES = 2      # minimum age before cashout is eligible


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


def compute_exit_reason(direction, cur_yes, entry_yes, age_placed, status,
                        cashout_adverse=CASHOUT_ADVERSE,
                        cashout_minutes=CASHOUT_MINUTES,
                        peak_yes=None):
    """
    Determine whether to exit a position and the reason.

    Returns (reason_str, exit_type) or (None, None) to hold.
    exit_type: 'hard_floor' | 'profit_lock' | 'break_even' | 'cashout' | None

    Priority order (highest first):
      1. hard_floor  — price at extreme limit, almost nothing left to salvage
      2. profit_lock — was winning, now reversing; lock remaining profit
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
    if direction == "UP":
        peak = peak_yes if peak_yes is not None else entry_yes
        reversal = (peak - cur_yes) > 0.08
    else:
        peak = peak_yes if peak_yes is not None else entry_yes
        reversal = (cur_yes - peak) > 0.08

    # Tighten threshold in the final 3 minutes of the window
    late_thresh = 0.05 if age_placed >= 12 else cashout_adverse

    if hard_floor and age_placed >= 0.5:
        return f"HardFloor YES={cur_yes:.2f}", "hard_floor"
    if win_prob > 0.70 and reversal and age_placed >= 1.5:
        return f"ProfitLock win={win_prob:.2f}", "profit_lock"
    if win_prob < 0.45 and age_placed >= 2.5 and entry_win > 0.60:
        return f"BreakEven {win_prob:.0%}", "break_even"
    if adverse > late_thresh and age_placed >= cashout_minutes:
        return f"CashOut adverse={adverse:.2f}", "cashout"
    return None, None
