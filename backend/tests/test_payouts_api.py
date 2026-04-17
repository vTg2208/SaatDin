"""Tests for the /api/v1/payouts endpoints."""
from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.app.api.payouts import router as payouts_router
from backend.app.core.security import create_access_token


def _build_client() -> TestClient:
    app = FastAPI()
    app.include_router(payouts_router, prefix="/api/v1/payouts")
    return TestClient(app)


_WORKER = {
    "phone": "9876543210",
    "name": "Raju",
    "platform_name": "Blinkit",
    "zone_pincode": "560103",
    "zone_name": "Bellandur",
    "plan_name": "Standard",
    "payout_primary_upi": "9876543210@saatdin",
    "payout_primary_verified": 1,
    "payout_backup_upi": None,
    "payout_backup_verified": 0,
    "payout_provider_contact": "9876543210",
}

_DASHBOARD = {
    "primaryUpi": "9876543210@saatdin",
    "primaryUpiMasked": "98*****@saatdin",
    "primaryVerified": True,
    "backupUpi": None,
    "backupUpiMasked": "",
    "backupVerified": False,
    "provider": "razorpay-sandbox-local",
    "summary": {
        "settledCount": 1,
        "settledTotal": 400.0,
        "pendingTotal": 0.0,
    },
    "transfers": [],
}


class PayoutDashboardTests(unittest.TestCase):
    def test_get_dashboard_returns_payout_info(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        with (
            patch("backend.app.core.dependencies.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
            patch("backend.app.api.payouts.get_worker_payout_dashboard", new=AsyncMock(return_value=_DASHBOARD)),
        ):
            response = client.get(
                "/api/v1/payouts/me",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        data = payload["data"]
        self.assertIn("primaryUpi", data)
        self.assertIn("summary", data)


class PayoutAccountUpdateTests(unittest.TestCase):
    def test_update_primary_upi(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        with (
            patch("backend.app.core.dependencies.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
            patch("backend.app.api.payouts.update_upi_account", new=AsyncMock(return_value=_DASHBOARD)),
        ):
            response = client.put(
                "/api/v1/payouts/accounts/primary",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={"upiId": "raju@upi"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])

    def test_update_upi_rejects_invalid_format(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        with (
            patch("backend.app.core.dependencies.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
            patch(
                "backend.app.api.payouts.update_upi_account",
                new=AsyncMock(side_effect=ValueError("Invalid UPI ID format")),
            ),
        ):
            response = client.put(
                "/api/v1/payouts/accounts/primary",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={"upiId": "invalidupi"},
            )

        self.assertEqual(response.status_code, 400)


class PayoutVerificationTests(unittest.TestCase):
    def test_verify_primary_upi_account(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        with (
            patch("backend.app.core.dependencies.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
            patch("backend.app.api.payouts.verify_upi_account", new=AsyncMock(return_value=_DASHBOARD)),
        ):
            response = client.post(
                "/api/v1/payouts/accounts/primary/verify",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])


if __name__ == "__main__":
    unittest.main()
