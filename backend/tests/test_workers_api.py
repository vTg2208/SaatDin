"""Tests for the /api/v1/workers and /api/v1/register endpoints."""
from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.app.api.workers import router as workers_router
from backend.app.core.security import create_access_token


def _build_client() -> TestClient:
    app = FastAPI()
    app.include_router(workers_router, prefix="/api/v1")
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
    "payout_primary_upi": "9876543210@saatdin",
    "payout_primary_verified": 1,
    "payout_backup_upi": None,
    "payout_backup_verified": 0,
    "payout_provider_contact": "9876543210",
    "created_at": "2026-01-01T00:00:00+00:00",
    "updated_at": "2026-01-01T00:00:00+00:00",
}


class WorkerStatusTests(unittest.TestCase):
    def test_status_returns_worker_if_exists(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        with (
            patch("backend.app.api.workers.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
        ):
            response = client.get(
                "/api/v1/workers/status",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        data = payload["data"]
        self.assertTrue(data["exists"])
        self.assertIsNotNone(data["worker"])
        self.assertEqual(data["worker"]["phone"], "9876543210")

    def test_status_returns_not_found_for_new_phone(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        with (
            patch("backend.app.api.workers.get_worker", new=AsyncMock(return_value=None)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
        ):
            response = client.get(
                "/api/v1/workers/status",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        data = payload["data"]
        self.assertFalse(data["exists"])


class WorkerProfileTests(unittest.TestCase):
    def test_get_profile_returns_worker_details(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        with (
            patch("backend.app.core.dependencies.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
            patch("backend.app.api.workers.total_settled_amount_for_phone", new=AsyncMock(return_value=1200.0)),
        ):
            response = client.get(
                "/api/v1/workers/me",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        data = payload["data"]
        self.assertEqual(data["name"], "Raju")
        self.assertEqual(data["platform"], "Blinkit")
        self.assertEqual(data["zone"], "Bellandur")
        self.assertEqual(data["totalEarnings"], 1200)


class WorkerUpdateTests(unittest.TestCase):
    def test_update_profile_changes_name(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        updated_worker = {**_WORKER, "name": "Raju Kumar"}
        with (
            patch("backend.app.core.dependencies.get_worker", new=AsyncMock(return_value=_WORKER)),
            patch("backend.app.core.dependencies.apply_due_pending_worker_plan", new=AsyncMock(return_value=False)),
            patch("backend.app.api.workers.upsert_worker", new=AsyncMock()),
            patch("backend.app.api.workers.get_worker", new=AsyncMock(return_value=updated_worker)),
            patch("backend.app.api.workers.total_settled_amount_for_phone", new=AsyncMock(return_value=0.0)),
        ):
            response = client.put(
                "/api/v1/workers/me",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={"name": "Raju Kumar"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        self.assertEqual(payload["data"]["name"], "Raju Kumar")


class WorkerRegistrationTests(unittest.TestCase):
    def test_register_creates_worker(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        with (
            patch("backend.app.api.workers.upsert_worker", new=AsyncMock()),
            patch("backend.app.api.workers.get_worker", new=AsyncMock(return_value=_WORKER)),
        ):
            response = client.post(
                "/api/v1/register",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={
                    "phone": "9876543210",
                    "platformName": "Blinkit",
                    "zone": "560103",
                    "planName": "Standard",
                    "name": "Raju",
                },
            )

        self.assertEqual(response.status_code, 201)
        payload = response.json()
        self.assertTrue(payload["success"])
        data = payload["data"]
        self.assertEqual(data["phone"], "9876543210")
        self.assertEqual(data["plan"], "Standard")

    def test_register_rejects_mismatched_phone(self) -> None:
        client = _build_client()
        token = create_access_token("9876543210")
        response = client.post(
            "/api/v1/register",
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            json={
                "phone": "1111111111",
                "platformName": "Blinkit",
                "zone": "560103",
                "planName": "Standard",
            },
        )
        self.assertEqual(response.status_code, 403)


if __name__ == "__main__":
    unittest.main()
