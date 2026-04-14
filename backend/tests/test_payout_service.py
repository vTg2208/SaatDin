"""Tests for the payout service logic (UPI validation, masking, and statement generation)."""
from __future__ import annotations

import unittest

from backend.app.services.payouts import mask_upi_id, validate_upi_id


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


if __name__ == "__main__":
    unittest.main()
