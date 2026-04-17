"""Tests for the /api/v1/health endpoint."""
from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.app.api.health import router as health_router


class HealthApiTests(unittest.TestCase):
    def _client(self) -> TestClient:
        app = FastAPI()
        app.include_router(health_router, prefix="/api/v1/health")
        return TestClient(app)

    def test_health_returns_ok_when_all_checks_pass(self) -> None:
        client = self._client()
        with (
            patch("backend.app.api.health.healthcheck_db", new=AsyncMock(return_value=True)),
            patch("backend.app.api.health.load_zone_map", return_value={"560103": {}}),
        ):
            response = client.get("/api/v1/health")

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "ok")
        self.assertTrue(data["checks"]["database"])
        self.assertTrue(data["checks"]["zone_data"])

    def test_health_returns_degraded_when_db_down(self) -> None:
        client = self._client()
        with (
            patch("backend.app.api.health.healthcheck_db", new=AsyncMock(return_value=False)),
            patch("backend.app.api.health.load_zone_map", return_value={"560103": {}}),
        ):
            response = client.get("/api/v1/health")

        self.assertEqual(response.status_code, 503)
        data = response.json()
        self.assertEqual(data["status"], "degraded")
        self.assertFalse(data["checks"]["database"])

    def test_health_returns_degraded_when_zone_data_empty(self) -> None:
        client = self._client()
        with (
            patch("backend.app.api.health.healthcheck_db", new=AsyncMock(return_value=True)),
            patch("backend.app.api.health.load_zone_map", return_value={}),
        ):
            response = client.get("/api/v1/health")

        self.assertEqual(response.status_code, 503)
        data = response.json()
        self.assertEqual(data["status"], "degraded")
        self.assertFalse(data["checks"]["zone_data"])


if __name__ == "__main__":
    unittest.main()
