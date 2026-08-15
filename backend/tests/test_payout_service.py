"""Tests for the payout service logic (UPI validation, masking, and statement generation)."""
from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, patch

from backend.app.services.payouts import initiate_claim_payout, mask_upi_id, validate_upi_id


class UpiValidationTests(unittest.TestCase):
    def test_valid_upi_id(self) -> None:
        self.assertTrue(validate_upi_id("raju@upi"))
        self.assertTrue(validate_upi_id("raju123@okaxis"))
        self.assertTrue(validate_upi_id("rider.name@paytm"))

    def test_invalid_upi_id(self) -> None:
        self.assertFalse(validate_upi_id(""))
        self.assertFalse(validate_upi_id("raju"))
        self.assertFalse(validate_upi_id("@upi"))
        self.assertFalse(validate_upi_id("r@u"))

    def test_upi_with_special_chars(self) -> None:
        self.assertTrue(validate_upi_id("raju-rider@upi"))
        self.assertTrue(validate_upi_id("raju_rider@upi"))
        self.assertTrue(validate_upi_id("raju.rider@upi"))


class UpiMaskingTests(unittest.TestCase):
    def test_mask_standard_upi(self) -> None:
        result = mask_upi_id("9876543210@saatdin")
        self.assertTrue(result.startswith("98"))
        self.assertTrue(result.endswith("@saatdin"))
        self.assertIn("*", result)

    def test_mask_short_upi(self) -> None:
        result = mask_upi_id("ab@upi")
        self.assertIn("@upi", result)

    def test_mask_none_returns_empty(self) -> None:
        self.assertEqual(mask_upi_id(None), "")

    def test_mask_empty_returns_empty(self) -> None:
        self.assertEqual(mask_upi_id(""), "")


class PayoutCoverageTests(unittest.IsolatedAsyncioTestCase):
    async def test_payout_rejects_worker_without_active_coverage(self) -> None:
        worker = {
            "phone": "9999999999",
            "platform_name": "Blinkit",
            "zone_pincode": "560001",
            "plan_name": "Standard",
            "payout_primary_upi": "9999999999@upi",
            "payout_primary_verified": 1,
        }
        claim = {
            "id": 17,
            "amount": 400.0,
            "created_at": "2026-08-15T12:00:00+00:00",
        }
        selected_plan = type("Plan", (), {"name": "Standard", "maxDaysPerWeek": 3})
        with (
            patch("backend.app.services.payouts._selected_plan_for_worker", return_value=selected_plan),
            patch(
                "backend.app.core.db.list_paid_premium_weeks_for_phone",
                new=AsyncMock(return_value=[]),
            ),
            patch(
                "backend.app.services.payouts.count_settled_claim_days_for_phone_since",
                new=AsyncMock(return_value=0),
            ),
            patch(
                "backend.app.services.payouts.create_payout_transfer",
                new=AsyncMock(return_value={"id": 91}),
            ),
            patch(
                "backend.app.services.payouts.set_claim_payout_transfer",
                new=AsyncMock(),
            ),
        ):
            with self.assertRaisesRegex(ValueError, "active policy"):
                await initiate_claim_payout(claim=claim, worker=worker)

    async def test_payout_rejects_unverified_upi_account(self) -> None:
        worker = {
            "phone": "9999999999",
            "platform_name": "Blinkit",
            "zone_pincode": "560001",
            "plan_name": "Standard",
            "payout_primary_upi": "9999999999@upi",
            "payout_primary_verified": 0,
        }
        claim = {
            "id": 18,
            "amount": 400.0,
            "created_at": "2026-08-15T12:00:00+00:00",
        }

        with self.assertRaisesRegex(ValueError, "verified payout UPI"):
            await initiate_claim_payout(claim=claim, worker=worker)


if __name__ == "__main__":
    unittest.main()
