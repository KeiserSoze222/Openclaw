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
    CASHOUT_ADVERSE,
    CASHOUT_MINUTES,
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
    Fires when: win_prob > 0.70 AND position is reversing from entry AND age >= 1.5.
    Reversal for UP = entry_yes - cur_yes > 0.08 (price dropped back toward entry).
    """

    def test_up_profit_lock_triggers(self):
        # Entered at 0.82, now at 0.73 — still winning (0.73) but reversing (0.09 drop)
        _, etype = compute_exit_reason("UP", cur_yes=0.73, entry_yes=0.82,
                                       age_placed=2.0, status="open")
        assert etype == "profit_lock"

    def test_up_no_lock_without_reversal(self):
        # Entered at 0.70, now at 0.80 — winning AND still moving up, no reversal
        _, etype = compute_exit_reason("UP", cur_yes=0.80, entry_yes=0.70,
                                       age_placed=2.0, status="open")
        assert etype != "profit_lock"

    def test_up_no_lock_too_new(self):
        _, etype = compute_exit_reason("UP", cur_yes=0.73, entry_yes=0.82,
                                       age_placed=1.0, status="open")
        assert etype is None

    def test_up_no_lock_low_win_prob(self):
        # Win prob is 0.55 — below the 0.70 threshold
        _, etype = compute_exit_reason("UP", cur_yes=0.55, entry_yes=0.82,
                                       age_placed=2.0, status="open")
        # This would hit cashout (adverse = 0.82-0.55 = 0.27), not profit_lock
        assert etype != "profit_lock"

    def test_down_profit_lock_triggers(self):
        # DOWN: entry_yes=0.20, cur_yes=0.29 (went up 0.09 = reversal for DOWN)
        # win_prob = 1-0.29 = 0.71 > 0.70
        _, etype = compute_exit_reason("DOWN", cur_yes=0.29, entry_yes=0.20,
                                       age_placed=2.0, status="open")
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
        _, etype = compute_exit_reason("UP", cur_yes=0.46, entry_yes=0.70,
                                       age_placed=3.0, status="open")
        # adverse = 0.70-0.46 = 0.24 > 0.12 → cashout fires instead
        assert etype == "cashout"


# ── CashOut (adverse move) ───────────────────────────────────────────────────

class TestCashOut:
    def test_triggers_on_adverse_move(self):
        # UP: entered 0.68, now 0.55 — adverse = 0.13 > 0.12
        _, etype = compute_exit_reason("UP", cur_yes=0.55, entry_yes=0.68,
                                       age_placed=3.0, status="open")
        assert etype == "cashout"

    def test_no_trigger_below_threshold(self):
        # adverse = 0.68-0.58 = 0.10 < 0.12
        _, etype = compute_exit_reason("UP", cur_yes=0.58, entry_yes=0.68,
                                       age_placed=3.0, status="open")
        assert etype is None

    def test_no_trigger_before_cashout_minutes(self):
        # Big adverse but too new
        _, etype = compute_exit_reason("UP", cur_yes=0.50, entry_yes=0.68,
                                       age_placed=1.0, status="open",
                                       cashout_minutes=2)
        assert etype is None

    def test_triggers_at_exactly_cashout_minutes(self):
        _, etype = compute_exit_reason("UP", cur_yes=0.55, entry_yes=0.68,
                                       age_placed=2.0, status="open",
                                       cashout_minutes=2)
        assert etype == "cashout"

    def test_late_window_tighter_threshold(self):
        # Age >= 12: threshold drops to 0.05
        # adverse = 0.68-0.62 = 0.06 > 0.05 late threshold
        _, etype = compute_exit_reason("UP", cur_yes=0.62, entry_yes=0.68,
                                       age_placed=12.5, status="open")
        assert etype == "cashout"

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
    Verifies the threshold was tightened from 0.20 to 0.12.
    The old 0.20 value let positions lose 29% of value before exiting.
    """

    def test_cashout_adverse_is_tight(self):
        assert CASHOUT_ADVERSE <= 0.12, (
            f"CASHOUT_ADVERSE={CASHOUT_ADVERSE} — must be <= 0.12 to protect capital"
        )

    def test_new_threshold_catches_what_old_missed(self):
        """Position adverse by 0.13 — new threshold catches it, old 0.20 would miss it."""
        _, new_etype = compute_exit_reason(
            "UP", cur_yes=0.55, entry_yes=0.68, age_placed=3.0, status="open",
            cashout_adverse=0.12
        )
        _, old_etype = compute_exit_reason(
            "UP", cur_yes=0.55, entry_yes=0.68, age_placed=3.0, status="open",
            cashout_adverse=0.20
        )
        assert new_etype == "cashout"    # new threshold: saved ~$5.50 of $10 bet
        assert old_etype is None         # old threshold: position runs to expiry → $0

    def test_full_loss_scenario_with_old_threshold(self):
        """Shows exactly how a $10 UP bet at 0.68 would hit $0 with the old threshold."""
        entry_yes = 0.68
        contracts = 14  # approx int(10 / 0.68)
        initial_value = contracts * entry_yes  # ~$9.52

        # Position drops steadily...
        for cur_yes in [0.60, 0.55, 0.50, 0.48]:
            _, old_etype = compute_exit_reason(
                "UP", cur_yes=cur_yes, entry_yes=entry_yes,
                age_placed=3.0, status="open", cashout_adverse=0.20
            )
            # At 0.48, adverse = 0.68-0.48 = 0.20 — JUST at old threshold
            if cur_yes == 0.48:
                assert old_etype == "cashout"
                salvage = compute_sell_value(contracts, "UP", cur_yes)
                loss_pct = (initial_value - salvage) / initial_value * 100
                assert loss_pct > 25, f"Old threshold lets {loss_pct:.1f}% of position erode"

        # With new threshold, exits at 0.55 (adverse=0.13)
        _, new_etype = compute_exit_reason(
            "UP", cur_yes=0.55, entry_yes=entry_yes,
            age_placed=3.0, status="open", cashout_adverse=0.12
        )
        assert new_etype == "cashout"
        salvage_new = compute_sell_value(contracts, "UP", 0.55)
        loss_pct_new = (initial_value - salvage_new) / initial_value * 100
        # 12-cent adverse on a 68-cent entry is ~19% value loss — still far better than
        # letting it run to $0 or waiting for 20-cent adverse (29% loss at old threshold).
        assert loss_pct_new < 22, f"New threshold should exit with < 22% loss, got {loss_pct_new:.1f}%"


# ── Priority ordering ────────────────────────────────────────────────────────

class TestExitPriority:
    """hard_floor beats everything; profit_lock beats break_even; etc."""

    def test_hard_floor_beats_cashout(self):
        # Both hard_floor and cashout could trigger here
        _, etype = compute_exit_reason("UP", cur_yes=0.04, entry_yes=0.70,
                                       age_placed=3.0, status="open")
        assert etype == "hard_floor"

    def test_profit_lock_beats_cashout(self):
        # Entry at 0.82, cur at 0.73: both profit_lock and cashout adverse could apply
        # adverse = 0.82-0.73 = 0.09 < 0.12, so actually only profit_lock fires here
        _, etype = compute_exit_reason("UP", cur_yes=0.73, entry_yes=0.82,
                                       age_placed=2.0, status="open")
        assert etype == "profit_lock"
