"""Tests for the /api/v1/policy endpoints."""
from __future__ import annotations

import unittest
from datetime import date, datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.app.api.policy import router as policy_router
from backend.app.core.security import create_access_token


def _build_client() -> TestClient:
    app = FastAPI()
    app.include_router(policy_router, prefix="/api/v1/policy")
    return TestClient(app)


_WORKER = {
    "phone": "9876543210",
    "name": "Raju",
    "platform_name": "Blinkit",
    "zone_pincode": "560103",
    "zone_name": "Bellandur",
    "plan_name": "Standard",
    "pending_plan_name": None,
    "pending_plan_effective_at": None,
}


class PolicyGetTests(unittest.TestCase):
    def test_get_policy_returns_active_policy(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        current_now = datetime.now(timezone.utc)
        current_week_start = current_now.date() - timedelta(days=current_now.weekday())
        with (
            patch("backend.app.core.dependencies.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
            patch("backend.app.api.policy.total_settled_amount_for_phone", new=AsyncMock(return_value=800.0)),
            patch(
                "backend.app.api.policy.list_paid_premium_weeks_for_phone",
                new=AsyncMock(return_value=[{"week_start_date": current_week_start}]),
            ),
        ):
            response = client.get(
                "/api/v1/policy/me",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        data = payload["data"]
        self.assertEqual(data["status"], "active")
        self.assertEqual(data["plan"], "Standard")
        self.assertTrue(data["parametricCoverageOn"])
        self.assertEqual(data["perTriggerPayout"], 400)
        self.assertEqual(data["maxDaysPerWeek"], 3)


class PolicyPlanUpdateTests(unittest.TestCase):
    def test_update_plan_queues_change(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        with (
            patch("backend.app.core.dependencies.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
            patch("backend.app.api.policy.set_pending_worker_plan", new=AsyncMock()),
            patch("backend.app.api.policy.total_settled_amount_for_phone", new=AsyncMock(return_value=0.0)),
            patch("backend.app.api.policy.list_paid_premium_weeks_for_phone", new=AsyncMock(return_value=[])),
        ):
            response = client.put(
                "/api/v1/policy/plan",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={"planName": "Premium"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        self.assertIn("queued", payload.get("message", "").lower())

    def test_update_plan_rejects_unknown_plan(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        with (
            patch("backend.app.core.dependencies.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
        ):
            response = client.put(
                "/api/v1/policy/plan",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={"planName": "NonexistentPlan"},
            )

        self.assertEqual(response.status_code, 400)


class PremiumPaymentTests(unittest.TestCase):
    def test_record_payment_rejects_client_report_when_disabled(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        with (
            patch("backend.app.core.dependencies.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
            patch.dict(
                "backend.app.core.config.settings.__dict__",
                {"allow_client_reported_premium_payments": False},
            ),
            patch("backend.app.api.policy.upsert_premium_payment_week", new=AsyncMock()),
            patch("backend.app.api.policy.set_pending_worker_plan", new=AsyncMock()),
            patch("backend.app.api.policy.total_settled_amount_for_phone", new=AsyncMock(return_value=0.0)),
            patch("backend.app.api.policy.list_paid_premium_weeks_for_phone", new=AsyncMock(return_value=[])),
        ):
            response = client.post(
                "/api/v1/policy/premium-payment",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={"amount": 60, "status": "paid"},
            )

        self.assertEqual(response.status_code, 403)
        self.assertIn("server-verified", response.text.lower())

    def test_record_payment_schedules_next_week_cycle(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        now = datetime.now(timezone.utc)
        next_cycle_start = (now.date() - timedelta(days=now.weekday())) + timedelta(days=7)

        with (
            patch("backend.app.core.dependencies.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
            patch("backend.app.api.policy.resolve_zone", return_value=("560103", {"name": "Bellandur", "zone_risk_multiplier": 1.0})),
            patch("backend.app.api.policy.build_plans", return_value=[
                type("Plan", (), {"name": "Basic", "weeklyPremium": 35, "perTriggerPayout": 250, "maxDaysPerWeek": 2}),
                type("Plan", (), {"name": "Standard", "weeklyPremium": 60, "perTriggerPayout": 400, "maxDaysPerWeek": 3}),
                type("Plan", (), {"name": "Premium", "weeklyPremium": 88, "perTriggerPayout": 550, "maxDaysPerWeek": 4}),
            ]),
            patch("backend.app.api.policy.upsert_premium_payment_week", new=AsyncMock()),
            patch("backend.app.api.policy.set_pending_worker_plan", new=AsyncMock()),
            patch("backend.app.api.policy.total_settled_amount_for_phone", new=AsyncMock(return_value=0.0)),
            patch("backend.app.api.policy.list_paid_premium_weeks_for_phone", new=AsyncMock(return_value=[{"week_start_date": next_cycle_start}])),
        ):
            response = client.post(
                "/api/v1/policy/premium-payment",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={"amount": 88, "status": "paid"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        data = payload["data"]
        self.assertEqual(data["status"], "scheduled")
        self.assertEqual(data["cycleStartDate"], next_cycle_start.isoformat())
        self.assertEqual(data["cycleEndDate"], (next_cycle_start + timedelta(days=6)).isoformat())
        self.assertEqual(data["amountPaidThisWeek"], 0.0)
        self.assertFalse(data["parametricCoverageOn"])


if __name__ == "__main__":
    unittest.main()
