#!/usr/bin/env python3
"""
Cashout exit-logic tests.

Covers:
  - Correct sell-side mapping (the bug that caused bets to go to $0)
  - sell_value calculation
  - Each exit trigger fires at the right threshold
  - Exit triggers do NOT fire prematurely
  - Boundary / edge cases
  - Regression: CASHOUT_ADVERSE must be <= 0.12
  - Dynamic ProfitLock thresholds (April 20 false-positive regression cases)
  - peak_yes parameter behavior
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from exit_logic import (
    compute_exit_reason,
    sell_side_for_direction,
    compute_win_prob,
    compute_adverse,
    compute_sell_value,
    compute_profitlock_win_floor,
    compute_reversal_threshold,
    compute_cashout_win_floor,
    CASHOUT_ADVERSE,
    CASHOUT_MINUTES,
    PROFITLOCK_MIN_AGE,
)


# ── sell_side_for_direction ──────────────────────────────────────────────────

class TestSellSide:
    """
    THE most critical test.
    When you buy YES (UP) you must sell YES to exit — not NO.
    The original bug sold the wrong side, causing every cashout to fail silently.
    """

    def test_up_direction_sells_yes(self):
        assert sell_side_for_direction("UP") == "yes"

    def test_down_direction_sells_no(self):
        assert sell_side_for_direction("DOWN") == "no"

    def test_up_is_not_no(self):
        """Regression: old code had 'no' for UP — verify that's gone."""
        assert sell_side_for_direction("UP") != "no"

    def test_down_is_not_yes(self):
        """Regression: old code had 'yes' for DOWN — verify that's gone."""
        assert sell_side_for_direction("DOWN") != "yes"


# ── compute_sell_value ───────────────────────────────────────────────────────

class TestSellValue:
    def test_up_value_uses_cur_yes(self):
        """For UP (YES contracts), sell price per contract = cur_yes."""
        assert compute_sell_value(10, "UP", 0.65) == pytest.approx(6.50)

    def test_down_value_uses_one_minus_yes(self):
        """For DOWN (NO contracts), sell price per contract = 1 - cur_yes."""
        assert compute_sell_value(10, "DOWN", 0.40) == pytest.approx(6.00)

    def test_up_near_zero_salvage(self):
        assert compute_sell_value(10, "UP", 0.05) == pytest.approx(0.50)

    def test_down_near_zero_salvage(self):
        assert compute_sell_value(10, "DOWN", 0.95) == pytest.approx(0.50)

    def test_up_winning_position(self):
        """UP position where YES is high — full near-dollar value."""
        assert compute_sell_value(10, "UP", 0.92) == pytest.approx(9.20)

    def test_down_winning_position(self):
        """DOWN position where YES is low — NO is near dollar."""
        assert compute_sell_value(10, "DOWN", 0.08) == pytest.approx(9.20)


# ── compute_adverse ──────────────────────────────────────────────────────────

class TestComputeAdverse:
    def test_up_adverse_when_yes_drops(self):
        """UP: adverse = entry_yes - cur_yes."""
        assert compute_adverse("UP", 0.55, 0.70) == pytest.approx(0.15)

    def test_up_not_adverse_when_yes_rises(self):
        """UP: position winning — adverse is negative."""
        assert compute_adverse("UP", 0.80, 0.70) == pytest.approx(-0.10)

    def test_down_adverse_when_yes_rises(self):
        """DOWN: entry_no=0.70, cur_yes=0.83, adverse=0.13."""
        assert compute_adverse("DOWN", 0.83, 0.30) == pytest.approx(0.13)

    def test_down_not_adverse_when_yes_drops(self):
        """DOWN: position winning — adverse is negative."""
        assert compute_adverse("DOWN", 0.20, 0.30) == pytest.approx(-0.50)


# ── HardFloor ────────────────────────────────────────────────────────────────

class TestHardFloor:
    def test_up_triggers_below_floor(self):
        _, etype = compute_exit_reason("UP", cur_yes=0.05, entry_yes=0.70,
                                       age_placed=1.0, status="open")
        assert etype == "hard_floor"

    def test_down_triggers_above_ceiling(self):
        _, etype = compute_exit_reason("DOWN", cur_yes=0.95, entry_yes=0.30,
                                       age_placed=1.0, status="open")
        assert etype == "hard_floor"

    def test_up_no_trigger_above_floor(self):
        _, etype = compute_exit_reason("UP", cur_yes=0.07, entry_yes=0.70,
                                       age_placed=1.0, status="open")
        assert etype != "hard_floor"

    def test_down_no_trigger_below_ceiling(self):
        _, etype = compute_exit_reason("DOWN", cur_yes=0.93, entry_yes=0.30,
                                       age_placed=1.0, status="open")
        assert etype != "hard_floor"

    def test_hard_floor_requires_age_half_minute(self):
        """Position must be at least 0.5 min old — very fresh positions are skipped."""
        _, etype = compute_exit_reason("UP", cur_yes=0.04, entry_yes=0.70,
                                       age_placed=0.3, status="open")
        assert etype is None

    def test_hard_floor_at_exactly_half_minute(self):
        _, etype = compute_exit_reason("UP", cur_yes=0.04, entry_yes=0.70,
                                       age_placed=0.5, status="open")
        assert etype == "hard_floor"


# ── ProfitLock ───────────────────────────────────────────────────────────────

class TestProfitLock:
    """
    Fires when: pl_floor > win_prob > 0.45 AND reversing from peak AND age >= 3.0 min.
    pl_floor is dynamic: 0.72 (entry_win>=0.85), 0.65 (entry_win>=0.70), 0.55 otherwise.
    Reversal threshold: 0.15 for high-conf entries (entry_win>=0.85), 0.08 otherwise.
    """

    def test_up_profit_lock_triggers(self):
        # entry=0.77 (entry_win=0.77, pl_floor=0.65), cur=0.61 (win_prob=0.61<pl_floor)
        # reversal=0.77-0.61=0.16>rev_thresh=0.08, age=4.0>=3.0 → fires
        _, etype = compute_exit_reason("UP", cur_yes=0.61, entry_yes=0.77,
                                       age_placed=4.0, status="open")
        assert etype == "profit_lock"

    def test_up_no_lock_without_reversal(self):
        # Position still moving up — no reversal, profit_lock does not fire
        _, etype = compute_exit_reason("UP", cur_yes=0.80, entry_yes=0.70,
                                       age_placed=4.0, status="open")
        assert etype != "profit_lock"

    def test_up_no_lock_too_new(self):
        # Conditions met but age=2.5 < PROFITLOCK_MIN_AGE=3.0 — blocked
        # adverse=0.73-0.62=0.11 < 0.12 so no cashout either → None
        _, etype = compute_exit_reason("UP", cur_yes=0.62, entry_yes=0.73,
                                       age_placed=2.5, status="open")
        assert etype is None

    def test_up_no_lock_win_prob_below_pl_zone(self):
        # win_prob=0.44 is below the ProfitLock minimum (0.45) — ProfitLock does not fire
        # (BreakEven fires instead for high-conviction entries)
        _, etype = compute_exit_reason("UP", cur_yes=0.44, entry_yes=0.82,
                                       age_placed=4.0, status="open")
        assert etype != "profit_lock"

    def test_down_profit_lock_triggers(self):
        # DOWN: entry_yes=0.20 (entry_win=0.80, pl_floor=0.65)
        # cur=0.37 → win_prob=0.63<pl_floor, reversal=0.37-0.20=0.17>0.08, age=4.0>=3.0 → fires
        _, etype = compute_exit_reason("DOWN", cur_yes=0.37, entry_yes=0.20,
                                       age_placed=4.0, status="open")
        assert etype == "profit_lock"


# ── BreakEven ────────────────────────────────────────────────────────────────

class TestBreakEven:
    """
    Fires when: win_prob < 0.45 AND age >= 2.5 AND entry was high-conviction (entry_win > 0.60).
    """

    def test_up_triggers(self):
        # Entered at 0.70 (confident UP), now 0.44 (losing), age 3+ min
        _, etype = compute_exit_reason("UP", cur_yes=0.44, entry_yes=0.70,
                                       age_placed=3.0, status="open")
        assert etype == "break_even"

    def test_up_no_trigger_too_soon(self):
        # Same scenario but only 2.0 min old — hits cashout first (adverse = 0.26 > 0.12)
        _, etype = compute_exit_reason("UP", cur_yes=0.44, entry_yes=0.70,
                                       age_placed=2.0, status="open")
        assert etype == "cashout"

    def test_up_no_trigger_low_conviction_entry(self):
        # entry_win = 0.55 <= 0.60 — BreakEven guard skips low-conviction entries
        _, etype = compute_exit_reason("UP", cur_yes=0.44, entry_yes=0.55,
                                       age_placed=3.0, status="open",
                                       cashout_adverse=0.12)
        # adverse = 0.55-0.44 = 0.11 < 0.12, no cashout either
        assert etype is None

    def test_down_triggers(self):
        # DOWN: entry_yes=0.30 (entry_no=0.70 — high conviction), cur_yes=0.57 (win_prob=0.43)
        _, etype = compute_exit_reason("DOWN", cur_yes=0.57, entry_yes=0.30,
                                       age_placed=3.0, status="open")
        assert etype == "break_even"

    def test_win_prob_just_above_threshold_no_trigger(self):
        # win_prob = 0.46 > 0.45 — should NOT trigger BreakEven
        # (ProfitLock or CashOut may fire instead, but not BreakEven)
        _, etype = compute_exit_reason("UP", cur_yes=0.46, entry_yes=0.70,
                                       age_placed=3.0, status="open")
        assert etype != "break_even"


# ── CashOut (adverse move) ───────────────────────────────────────────────────

class TestCashOut:
    def test_adverse_alone_no_longer_triggers_cashout(self):
        # UP: entered 0.68, now 0.55 — adverse=0.13>0.12 but win_prob=0.55>floor(0.50)
        # Win-probability floor blocks CashOut when position is still above break-even.
        _, etype = compute_exit_reason("UP", cur_yes=0.55, entry_yes=0.68,
                                       age_placed=3.0, status="open")
        assert etype != "cashout"

    def test_no_trigger_below_threshold(self):
        # adverse = 0.68-0.58 = 0.10 < 0.12
        _, etype = compute_exit_reason("UP", cur_yes=0.58, entry_yes=0.68,
                                       age_placed=3.0, status="open")
        assert etype is None

    def test_no_trigger_before_cashout_minutes(self):
        # Big adverse and win_prob<=floor but position too new
        _, etype = compute_exit_reason("UP", cur_yes=0.48, entry_yes=0.68,
                                       age_placed=1.0, status="open",
                                       cashout_minutes=2)
        assert etype is None

    def test_triggers_at_exactly_cashout_minutes(self):
        # win_prob=0.48 <= floor(0.50), adverse=0.20>0.12, age=2.0 at exact threshold
        _, etype = compute_exit_reason("UP", cur_yes=0.48, entry_yes=0.68,
                                       age_placed=2.0, status="open",
                                       cashout_minutes=2)
        assert etype == "cashout"

    def test_late_window_tighter_threshold(self):
        # Age >= 12: threshold drops to 0.05
        # UP: entry=0.55 (entry_win=0.55<0.60 → floor=0.0), cur=0.49
        # adverse=0.06 > 0.05 late threshold, reversal=0.06 < rev_thresh=0.08 → ProfitLock blocked
        # BreakEven blocked (entry_win=0.55 not >0.60); CashOut fires (floor=0.0, adverse-only)
        _, etype = compute_exit_reason("UP", cur_yes=0.49, entry_yes=0.55,
                                       age_placed=12.5, status="open")
        assert etype == "cashout"

    def test_late_window_blocked_by_win_floor(self):
        # Age >= 12, adverse=0.06>0.05 (late threshold passes), but win_prob=0.62>floor → hold
        _, etype = compute_exit_reason("UP", cur_yes=0.62, entry_yes=0.68,
                                       age_placed=12.5, status="open")
        assert etype is None

    def test_late_window_below_late_threshold(self):
        # adverse = 0.68-0.65 = 0.03 < 0.05 late threshold
        _, etype = compute_exit_reason("UP", cur_yes=0.65, entry_yes=0.68,
                                       age_placed=12.5, status="open")
        assert etype is None

    def test_down_cashout(self):
        # DOWN: entry_yes=0.40 (entry_no=0.60, exactly at BreakEven boundary so BreakEven
        # does NOT fire since entry_win=0.60 is not > 0.60).
        # cur_yes=0.73 → adverse=0.73-0.60=0.13 > 0.12 → cashout fires.
        _, etype = compute_exit_reason("DOWN", cur_yes=0.73, entry_yes=0.40,
                                       age_placed=3.0, status="open")
        assert etype == "cashout"

    def test_down_no_cashout_winning(self):
        # DOWN winning: YES dropped below entry
        _, etype = compute_exit_reason("DOWN", cur_yes=0.10, entry_yes=0.30,
                                       age_placed=3.0, status="open")
        assert etype is None


# ── No exit conditions ───────────────────────────────────────────────────────

class TestNoExit:
    def test_holding_winning_up_position(self):
        # UP: entered 0.68, now 0.80, winning, no reversal
        _, etype = compute_exit_reason("UP", cur_yes=0.80, entry_yes=0.68,
                                       age_placed=3.0, status="open")
        assert etype is None

    def test_holding_winning_down_position(self):
        # DOWN: entered 0.30, YES dropped to 0.15 — winning
        _, etype = compute_exit_reason("DOWN", cur_yes=0.15, entry_yes=0.30,
                                       age_placed=3.0, status="open")
        assert etype is None

    def test_closed_market_skipped(self):
        _, etype = compute_exit_reason("UP", cur_yes=0.05, entry_yes=0.70,
                                       age_placed=5.0, status="closed")
        assert etype is None

    def test_unknown_direction_skipped(self):
        _, etype = compute_exit_reason("UNKNOWN", cur_yes=0.05, entry_yes=0.70,
                                       age_placed=5.0, status="open")
        assert etype is None

    def test_position_at_entry_no_exit(self):
        # No movement at all
        _, etype = compute_exit_reason("UP", cur_yes=0.68, entry_yes=0.68,
                                       age_placed=3.0, status="open")
        assert etype is None


# ── CASHOUT_ADVERSE threshold regression ────────────────────────────────────

class TestCashOutThresholdRegression:
    """
    Verifies the threshold was tightened from 0.20 to 0.12, and the win-probability
    floor (0.50 for entry_win>=0.60) prevents CashOut from firing on winning positions.

    Historical simulation (390 trades Mar-Apr 2026) proved that T=0.12 without a floor
    produced a 97% false-positive rate — 97 winning positions exited vs 3 losses caught.
    The floor is now the primary gate; the threshold matters within the floor zone.
    """

    def test_cashout_adverse_is_tight(self):
        assert CASHOUT_ADVERSE <= 0.12, (
            f"CASHOUT_ADVERSE={CASHOUT_ADVERSE} — must be <= 0.12 to protect capital"
        )

    def test_new_threshold_catches_what_old_missed(self):
        """
        Win-probability floor (0.50) blocks CashOut when position is still winning.
        At win_prob=0.55 (above floor), CashOut is blocked regardless of threshold.
        In the floor zone (win_prob=0.48), T=0.12 catches at adverse=0.20; T=0.25 misses.
        age=2.0 keeps ProfitLock (requires age>=3.0) from firing first.
        """
        # Above floor: both thresholds blocked (floor is primary gate)
        _, new_etype = compute_exit_reason(
            "UP", cur_yes=0.55, entry_yes=0.68, age_placed=2.0, status="open",
            cashout_adverse=0.12
        )
        _, old_etype = compute_exit_reason(
            "UP", cur_yes=0.55, entry_yes=0.68, age_placed=2.0, status="open",
            cashout_adverse=0.20
        )
        assert new_etype != "cashout"   # floor blocks — position still 55% likely to win
        assert old_etype != "cashout"   # same — threshold irrelevant above floor

        # In floor zone (win_prob=0.48): threshold now matters
        _, tight_etype = compute_exit_reason(
            "UP", cur_yes=0.48, entry_yes=0.68, age_placed=2.0, status="open",
            cashout_adverse=0.12
        )
        _, loose_etype = compute_exit_reason(
            "UP", cur_yes=0.48, entry_yes=0.68, age_placed=2.0, status="open",
            cashout_adverse=0.25
        )
        assert tight_etype == "cashout"   # T=0.12 exits at 29% loss (adverse=0.20)
        assert loose_etype is None         # T=0.25 still waiting — adverse=0.20 < 0.25

    def test_full_loss_scenario_with_old_threshold(self):
        """
        Position declining from entry=0.68. The floor holds it above 0.50 (still winning);
        once it crosses below 0.50, CashOut fires and salvages remaining value.
        age=2.0 isolates CashOut (ProfitLock requires age>=3.0).
        """
        entry_yes = 0.68
        contracts = 14  # approx int(10 / 0.68)
        initial_value = contracts * entry_yes  # ~$9.52

        # Above floor: hold throughout (position still >50% chance of winning)
        for cur_yes in [0.65, 0.60, 0.55, 0.51]:
            _, etype = compute_exit_reason(
                "UP", cur_yes=cur_yes, entry_yes=entry_yes,
                age_placed=2.0, status="open"
            )
            assert etype != "cashout", (
                f"Should hold at win_prob={cur_yes:.2f} > floor=0.50"
            )

        # Crosses below floor (win_prob=0.48): CashOut exits to salvage value
        _, floor_etype = compute_exit_reason(
            "UP", cur_yes=0.48, entry_yes=entry_yes,
            age_placed=2.0, status="open"
        )
        assert floor_etype == "cashout"
        salvage = compute_sell_value(contracts, "UP", 0.48)
        loss_pct = (initial_value - salvage) / initial_value * 100
        # Exiting at 48¢ vs 68¢ entry: ~30% value loss but $6.72 salvaged vs $0 at expiry
        assert loss_pct < 35, f"Floor exit with {loss_pct:.1f}% loss — better than $0"


# ── Priority ordering ────────────────────────────────────────────────────────

class TestExitPriority:
    """hard_floor beats everything; profit_lock beats break_even; etc."""

    def test_hard_floor_beats_cashout(self):
        # Both hard_floor and cashout could trigger here
        _, etype = compute_exit_reason("UP", cur_yes=0.04, entry_yes=0.70,
                                       age_placed=3.0, status="open")
        assert etype == "hard_floor"

    def test_profit_lock_beats_cashout(self):
        # entry=0.78 (entry_win=0.78, pl_floor=0.65), cur=0.60 → win_prob=0.60<pl_floor
        # adverse=0.18>0.12 so cashout also eligible — profit_lock fires first (higher priority)
        _, etype = compute_exit_reason("UP", cur_yes=0.60, entry_yes=0.78,
                                       age_placed=4.0, status="open")
        assert etype == "profit_lock"


# ── peak_yes parameter (ProfitLock reversal detection) ───────────────────────

class TestPeakYes:
    """
    ProfitLock uses best price seen (peak_yes) as reversal anchor, not entry_yes.
    Without peak_yes, reversal is measured from entry_yes (conservative).
    """

    def test_up_profit_lock_fires_with_peak_yes(self):
        # UP: entry=0.70 (pl_floor=0.65), peak rose to 0.92, now at 0.63 (win_prob=0.63<pl_floor)
        # With peak: reversal=0.92-0.63=0.29>rev_thresh=0.08, age=4.0>=3.0 → fires
        _, etype = compute_exit_reason("UP", cur_yes=0.63, entry_yes=0.70,
                                       age_placed=4.0, status="open",
                                       peak_yes=0.92)
        assert etype == "profit_lock"

    def test_up_profit_lock_misses_without_peak_yes(self):
        # Same but no peak_yes → reversal=entry-cur=0.70-0.63=0.07<rev_thresh=0.08 → no lock
        # adverse=0.07<0.12, no cashout either → None
        _, etype = compute_exit_reason("UP", cur_yes=0.63, entry_yes=0.70,
                                       age_placed=4.0, status="open")
        assert etype is None

    def test_down_profit_lock_fires_with_peak_yes(self):
        # DOWN: entry_yes=0.30 (entry_win=0.70, pl_floor=0.65)
        # peak_yes=0.08 (YES dropped to 0.08 at peak win), cur=0.37 (win_prob=0.63<pl_floor)
        # With peak: reversal=cur-peak=0.37-0.08=0.29>0.08, age=4.0>=3.0 → fires
        _, etype = compute_exit_reason("DOWN", cur_yes=0.37, entry_yes=0.30,
                                       age_placed=4.0, status="open",
                                       peak_yes=0.08)
        assert etype == "profit_lock"

    def test_down_profit_lock_misses_without_peak_yes(self):
        # Same but no peak_yes → reversal=cur-entry=0.37-0.30=0.07<0.08 → no lock
        _, etype = compute_exit_reason("DOWN", cur_yes=0.37, entry_yes=0.30,
                                       age_placed=4.0, status="open")
        assert etype is None

    def test_peak_yes_none_falls_back_to_entry(self):
        # Explicit peak_yes=None behaves same as omitting it
        _, etype1 = compute_exit_reason("UP", cur_yes=0.78, entry_yes=0.60,
                                        age_placed=4.0, status="open",
                                        peak_yes=None)
        _, etype2 = compute_exit_reason("UP", cur_yes=0.78, entry_yes=0.60,
                                        age_placed=4.0, status="open")
        assert etype1 == etype2

    def test_peak_same_as_entry_no_spurious_trigger(self):
        # peak_yes == entry_yes: no extra reversal sensitivity introduced
        _, etype = compute_exit_reason("UP", cur_yes=0.72, entry_yes=0.68,
                                       age_placed=4.0, status="open",
                                       peak_yes=0.68)
        assert etype is None


# ── Dynamic ProfitLock — April 20 regression cases ──────────────────────────

class TestDynamicProfitLock:
    """
    Regression tests for the two false-positive exits observed on April 20 2026.

    Case 1 (SOL DOWN): entry YES=0.13 (entry_win=0.87), ProfitLock fired at YES=0.25
    (win_prob=0.75) — position would have WON.  Old code fired because 0.75>0.70.
    New code: pl_floor=0.72 for entry_win>=0.85; win_prob=0.75 is ABOVE the floor → hold.

    Case 3 (BTC DOWN): entry YES=0.10 (entry_win=0.90), ProfitLock fired at YES=0.19
    (win_prob=0.81).  New code: reversal=0.09<rev_thresh=0.15 for high-conf → hold.
    """

    def test_case1_sol_down_no_spurious_exit(self):
        # win_prob=0.75 is NOT below pl_floor=0.72, reversal=0.12<rev_thresh=0.15 → hold
        _, etype = compute_exit_reason("DOWN", cur_yes=0.25, entry_yes=0.13,
                                       age_placed=4.0, status="open")
        assert etype is None

    def test_case3_btc_down_no_spurious_exit(self):
        # win_prob=0.81 NOT below pl_floor=0.72, reversal=0.09<rev_thresh=0.15 → hold
        _, etype = compute_exit_reason("DOWN", cur_yes=0.19, entry_yes=0.10,
                                       age_placed=4.0, status="open")
        assert etype is None

    def test_high_conf_fires_on_large_reversal(self):
        # Same high-conf DOWN setup, but reversal=0.22>0.15 AND win_prob=0.65<pl_floor=0.72
        _, etype = compute_exit_reason("DOWN", cur_yes=0.35, entry_yes=0.13,
                                       age_placed=4.0, status="open")
        assert etype == "profit_lock"

    def test_min_hold_time_blocks_early_exit(self):
        # Same conditions as above but age=2.5 < PROFITLOCK_MIN_AGE=3.0 → blocked
        _, etype = compute_exit_reason("DOWN", cur_yes=0.35, entry_yes=0.13,
                                       age_placed=2.5, status="open")
        assert etype is None

    def test_min_hold_time_allows_exit_after_3min(self):
        # age just crosses 3.0 → fires
        _, etype = compute_exit_reason("DOWN", cur_yes=0.35, entry_yes=0.13,
                                       age_placed=3.1, status="open")
        assert etype == "profit_lock"

    def test_high_conf_floor_boundary_no_lock(self):
        # UP, entry=0.90 (pl_floor=0.72); win_prob=0.72 exactly at floor
        # 0.72 > 0.72 is False → ProfitLock does NOT fire (strict inequality)
        _, etype = compute_exit_reason("UP", cur_yes=0.72, entry_yes=0.90,
                                       age_placed=4.0, status="open")
        assert etype != "profit_lock"

    def test_high_conf_floor_fires_just_below(self):
        # win_prob=0.71 just below pl_floor=0.72, reversal=0.19>rev_thresh=0.15 → fires
        _, etype = compute_exit_reason("UP", cur_yes=0.71, entry_yes=0.90,
                                       age_placed=4.0, status="open")
        assert etype == "profit_lock"

    def test_mid_conf_floor_no_lock_above_floor(self):
        # entry=0.78 (pl_floor=0.65), win_prob=0.67>pl_floor → ProfitLock does not fire
        _, etype = compute_exit_reason("UP", cur_yes=0.67, entry_yes=0.78,
                                       age_placed=4.0, status="open")
        assert etype != "profit_lock"

    def test_mid_conf_floor_fires_below_0_65(self):
        # Same but win_prob=0.62<pl_floor=0.65, reversal=0.16>0.08 → fires
        _, etype = compute_exit_reason("UP", cur_yes=0.62, entry_yes=0.78,
                                       age_placed=4.0, status="open")
        assert etype == "profit_lock"


# ── Helper-function unit tests ───────────────────────────────────────────────

class TestDynamicThresholds:
    """Unit tests for compute_profitlock_win_floor and compute_reversal_threshold."""

    def test_floor_high_conf_at_boundary(self):
        assert compute_profitlock_win_floor(0.85) == pytest.approx(0.72)

    def test_floor_high_conf_above_boundary(self):
        assert compute_profitlock_win_floor(0.92) == pytest.approx(0.72)

    def test_floor_mid_conf_at_boundary(self):
        assert compute_profitlock_win_floor(0.70) == pytest.approx(0.65)

    def test_floor_mid_conf_upper(self):
        assert compute_profitlock_win_floor(0.84) == pytest.approx(0.65)

    def test_floor_low_conf(self):
        assert compute_profitlock_win_floor(0.50) == pytest.approx(0.55)

    def test_floor_low_conf_boundary(self):
        assert compute_profitlock_win_floor(0.69) == pytest.approx(0.55)

    def test_reversal_thresh_high_conf(self):
        assert compute_reversal_threshold(0.85) == pytest.approx(0.15)

    def test_reversal_thresh_high_conf_above(self):
        assert compute_reversal_threshold(1.00) == pytest.approx(0.15)

    def test_reversal_thresh_normal(self):
        assert compute_reversal_threshold(0.84) == pytest.approx(0.08)

    def test_reversal_thresh_low(self):
        assert compute_reversal_threshold(0.50) == pytest.approx(0.08)

    def test_profitlock_min_age_constant(self):
        assert PROFITLOCK_MIN_AGE == pytest.approx(3.0)


# ── CashOut win-probability floor (Task 3 — April 2026) ─────────────────────

class TestCashoutWinFloor:
    """
    CashOut is now gated by a win-probability floor.

    Historical simulation (390 trades Mar-Apr 2026) at T=0.12:
      BTC  44/46 FP (96%)  ETH  29/30 FP (97%)  SOL  24/24 FP (100%)
      TOTAL 97 false positives vs 3 true positives — 97% FP rate.

    All directional entries have entry_win >= 0.68 (DIRECTIONAL_HIGH=0.68).
    Losses are rapid collapses, not gradual drift CashOut can intercept.
    Floor=0.50 confines CashOut to positions that have genuinely crossed
    to losing territory; BreakEven (win_prob<0.45) provides the primary net.
    """

    # ── compute_cashout_win_floor unit tests ─────────────────────────────────

    def test_floor_high_confidence_entry(self):
        assert compute_cashout_win_floor(0.85) == pytest.approx(0.50)

    def test_floor_mid_confidence_entry(self):
        assert compute_cashout_win_floor(0.70) == pytest.approx(0.50)

    def test_floor_at_directional_high_boundary(self):
        # DIRECTIONAL_HIGH=0.68 is the minimum real entry_win — floor=0.50
        assert compute_cashout_win_floor(0.68) == pytest.approx(0.50)

    def test_floor_at_threshold_exactly(self):
        # entry_win = 0.60 → boundary → floor=0.50
        assert compute_cashout_win_floor(0.60) == pytest.approx(0.50)

    def test_floor_just_below_threshold(self):
        # entry_win = 0.59 < 0.60 → floor=0.0 (adverse-only)
        assert compute_cashout_win_floor(0.59) == pytest.approx(0.0)

    def test_floor_very_low_confidence(self):
        assert compute_cashout_win_floor(0.40) == pytest.approx(0.0)

    # ── CashOut BLOCKED while still winning (win_prob > floor) ───────────────

    def test_no_cashout_above_floor_large_adverse(self):
        # UP: entry=0.78, cur=0.65 — adverse=0.13>0.12 but win_prob=0.65>0.50 → hold
        _, etype = compute_exit_reason("UP", cur_yes=0.65, entry_yes=0.78,
                                       age_placed=3.0, status="open")
        assert etype != "cashout"

    def test_no_cashout_at_floor_plus_one(self):
        # win_prob = 0.51, one tick above floor — blocked
        _, etype = compute_exit_reason("UP", cur_yes=0.51, entry_yes=0.68,
                                       age_placed=2.0, status="open")
        assert etype != "cashout"

    # ── April 21 live false-positive regressions ─────────────────────────────

    def test_eth_up_0639_false_positive_blocked(self):
        """
        ETH UP 06:39 AM April 21: entry≈0.69, cur≈0.51, win_prob=0.51 > floor.
        Old logic fired CashOut, costing $3.91 exit + $5.23 missed payout = $9.14.
        New floor blocks this exit — position correctly held.
        """
        _, etype = compute_exit_reason("UP", cur_yes=0.51, entry_yes=0.69,
                                       age_placed=3.0, status="open")
        assert etype != "cashout"

    def test_btc_up_0618_false_positive_blocked(self):
        """
        BTC UP 06:18 AM April 21: entry≈0.78, cur≈0.58, win_prob=0.58 > floor.
        Old logic fired CashOut, costing $4.13 exit + $3.74 missed payout = $7.87.
        New floor blocks this exit — position correctly held.
        """
        _, etype = compute_exit_reason("UP", cur_yes=0.58, entry_yes=0.78,
                                       age_placed=3.0, status="open")
        assert etype != "cashout"

    # ── CashOut FIRES when genuinely losing (win_prob <= floor) ─────────────

    def test_cashout_fires_at_exactly_floor(self):
        # win_prob=0.50 exactly at floor (<=), adverse > threshold — fires
        # age=2.0 keeps ProfitLock (age>=3.0) and BreakEven (age>=2.5) silent
        _, etype = compute_exit_reason("UP", cur_yes=0.50, entry_yes=0.68,
                                       age_placed=2.0, status="open")
        assert etype == "cashout"

    def test_cashout_fires_just_below_floor(self):
        # win_prob=0.48, adverse=0.20>0.12, age=2.0 → fires
        _, etype = compute_exit_reason("UP", cur_yes=0.48, entry_yes=0.68,
                                       age_placed=2.0, status="open")
        assert etype == "cashout"

    def test_sol_up_0802_correct_cashout_fires(self):
        """
        SOL UP 08:02 AM April 21: entry≈0.74, cur≈0.47, win_prob=0.47 < floor.
        New logic correctly exits — market says 47% chance of winning.
        At age=3.0, ProfitLock fires (pl_floor=0.65>0.47>0.45, reversal=0.27>0.08).
        Any of the three exit mechanisms is the correct outcome here.
        """
        _, etype = compute_exit_reason("UP", cur_yes=0.47, entry_yes=0.74,
                                       age_placed=3.0, status="open")
        assert etype in ("break_even", "cashout", "profit_lock")

    # ── Low-confidence entries preserve adverse-only logic ───────────────────

    def test_low_confidence_entry_cashout_still_works(self):
        # entry_win=0.55 < 0.60 → floor=0.0 → adverse-only (BreakEven blocked: entry_win not >0.60)
        _, etype = compute_exit_reason("UP", cur_yes=0.42, entry_yes=0.55,
                                       age_placed=3.0, status="open")
        assert etype == "cashout"

    def test_low_confidence_entry_floor_is_zero(self):
        assert compute_cashout_win_floor(0.55) == pytest.approx(0.0)

    # ── Interaction with BreakEven (win_prob < 0.45 takes priority) ──────────

    def test_breakeven_still_fires_below_its_threshold(self):
        # win_prob=0.44 < 0.45, age=3.0>=2.5, entry_win=0.70>0.60 → BreakEven, not CashOut
        _, etype = compute_exit_reason("UP", cur_yes=0.44, entry_yes=0.70,
                                       age_placed=3.0, status="open")
        assert etype == "break_even"

    def test_cashout_zone_between_floor_and_breakeven(self):
        # win_prob in (0.45, 0.50]: CashOut is the exit mechanism (BreakEven blocked)
        # age=2.0: ProfitLock (age<3.0) and BreakEven (age<2.5) both silent
        _, etype = compute_exit_reason("UP", cur_yes=0.46, entry_yes=0.68,
                                       age_placed=2.0, status="open")
        assert etype == "cashout"
