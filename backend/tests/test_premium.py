"""Tests for the premium calculation and plan building logic."""
from __future__ import annotations

import unittest

from backend.app.models.platform import Platform
from backend.app.services.premium import build_plans, calculate_premium


class PremiumCalculationTests(unittest.TestCase):
    def test_calculate_premium_basic_blinkit(self) -> None:
        result = calculate_premium(zone_multiplier=1.0, platform=Platform.blinkit, tier="basic")
        self.assertIsInstance(result, int)
        self.assertGreater(result, 0)
        # Base 45 × 1.0 × 1.10 × 0.72 = 35.64 → 36
        self.assertEqual(result, 36)

    def test_calculate_premium_standard_swiggy(self) -> None:
        result = calculate_premium(zone_multiplier=1.2, platform=Platform.swiggy_instamart, tier="standard")
        self.assertIsInstance(result, int)
        # Base 45 × 1.2 × 1.00 × 0.95 = 51.3 → 51
        self.assertEqual(result, 51)

    def test_calculate_premium_premium_zepto(self) -> None:
        result = calculate_premium(zone_multiplier=1.5, platform=Platform.zepto, tier="premium")
        self.assertIsInstance(result, int)
        # Base 45 × 1.5 × 1.10 × 1.25 = 92.8125 → 93
        self.assertEqual(result, 93)

    def test_higher_zone_multiplier_increases_premium(self) -> None:
        low = calculate_premium(zone_multiplier=1.0, platform=Platform.blinkit, tier="standard")
        high = calculate_premium(zone_multiplier=1.8, platform=Platform.blinkit, tier="standard")
        self.assertGreater(high, low)


class BuildPlansTests(unittest.TestCase):
    def test_build_plans_returns_three_tiers(self) -> None:
        plans = build_plans(zone_multiplier=1.0, platform=Platform.blinkit)
        self.assertEqual(len(plans), 3)
        names = [p.name for p in plans]
        self.assertEqual(names, ["Basic", "Standard", "Premium"])

    def test_build_plans_standard_is_popular(self) -> None:
        plans = build_plans(zone_multiplier=1.0, platform=Platform.swiggy_instamart)
        standard = next(p for p in plans if p.name == "Standard")
        self.assertTrue(standard.isPopular)

    def test_build_plans_payout_tiers(self) -> None:
        plans = build_plans(zone_multiplier=1.0, platform=Platform.blinkit)
        self.assertEqual(plans[0].perTriggerPayout, 250)
        self.assertEqual(plans[1].perTriggerPayout, 400)
        self.assertEqual(plans[2].perTriggerPayout, 550)

    def test_build_plans_max_days(self) -> None:
        plans = build_plans(zone_multiplier=1.0, platform=Platform.blinkit)
        self.assertEqual(plans[0].maxDaysPerWeek, 2)
        self.assertEqual(plans[1].maxDaysPerWeek, 3)
        self.assertEqual(plans[2].maxDaysPerWeek, 4)


if __name__ == "__main__":
    unittest.main()
