from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.app.api.triggers import router as triggers_router
from backend.app.core.dependencies import get_current_worker


class TriggersApiTests(unittest.TestCase):
    def _client(self) -> TestClient:
        app = FastAPI()
        app.include_router(triggers_router, prefix="/api/v1/triggers")
        app.dependency_overrides[get_current_worker] = lambda: {
            "phone": "9999999999",
            "zone_pincode": "560001",
            "zone_name": "Indiranagar",
            "name": "Worker",
            "platform_name": "Blinkit",
            "plan_name": "Standard",
        }
        return TestClient(app)

    def test_active_trigger_prefers_live_state(self) -> None:
        client = self._client()
        with (
            patch("backend.app.api.triggers.resolve_zone", return_value=("560001", {"flood_risk_score": 0.1})),
            patch(
                "backend.app.api.triggers.get_live_trigger_state",
                return_value={
                    "560001": {
                        "hasActiveAlert": True,
                        "alertType": "rain",
                        "alertTitle": "RainLock active",
                        "alertDescription": "Heavy rainfall detected.",
                        "confidence": 0.93,
                    }
                },
            ),
        ):
            response = client.get("/api/v1/triggers/active?zone=560001")

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["data"]["hasActiveAlert"])
        self.assertEqual(payload["data"]["alertType"], "rain")

    def test_zonelock_report_auto_confirms_on_corroboration(self) -> None:
        from datetime import datetime, timedelta, timezone

        now = datetime.now(timezone.utc)
        recent_ts = (now - timedelta(minutes=5)).isoformat()
        recent_ts_2 = (now - timedelta(minutes=10)).isoformat()

        client = self._client()
        with (
            patch(
                "backend.app.api.triggers.classify_disruption_text",
                return_value={"category": "curfew", "confidence": 0.91, "keywords": ["curfew", "police"]},
            ),
            patch(
                "backend.app.api.triggers.create_zonelock_report",
                new=AsyncMock(
                    return_value={
                        "id": 11,
                        "phone": "9999999999",
                        "zone_pincode": "560001",
                        "zone_name": "Indiranagar",
                        "description": "Police curfew near dark store",
                        "status": "pending_review",
                        "confidence": 0.4,
                        "verified_count": 1,
                        "created_at": recent_ts,
                    }
                ),
            ),
            patch(
                "backend.app.api.triggers.list_zonelock_reports_for_zone",
                new=AsyncMock(
                    return_value=[
                        {
                            "id": 11,
                            "phone": "9999999999",
                            "created_at": recent_ts,
                            "normalized_keywords": ["curfew", "police"],
                        },
                        {
                            "id": 12,
                            "phone": "9000000001",
                            "created_at": recent_ts_2,
                            "normalized_keywords": ["curfew", "police"],
                        },
                    ]
                ),
            ),
            patch("backend.app.api.triggers.increment_zonelock_report_verification", new=AsyncMock()),
            patch(
                "backend.app.api.triggers.get_zonelock_report",
                new=AsyncMock(
                    return_value={
                        "id": 11,
                        "zone_pincode": "560001",
                        "zone_name": "Indiranagar",
                        "description": "Police curfew near dark store",
                        "status": "auto_confirmed",
                        "confidence": 0.8,
                        "verified_count": 2,
                        "created_at": recent_ts,
                    }
                ),
            ),
            patch("backend.app.api.triggers.mark_zonelock_reports_auto_claimed", new=AsyncMock()),
            patch(
                "backend.app.api.triggers.force_trigger_for_zone",
                new=AsyncMock(return_value={"autoClaimsCreated": 4}),
            ),
        ):
            response = client.post(
                "/api/v1/triggers/zonelock/report",
                json={"description": "Police curfew near dark store"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        self.assertEqual(payload["data"]["status"], "auto_confirmed")
        self.assertEqual(payload["data"]["verifiedCount"], 2)


if __name__ == "__main__":
    unittest.main()

