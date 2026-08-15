from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.app.api.triggers import router as triggers_router
from backend.app.core.dependencies import get_admin_actor, get_current_worker
from backend.app.services.trigger_monitor import _determine_trigger, force_trigger_for_zone


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

    def test_force_trigger_requires_admin_authentication(self) -> None:
        client = self._client()
        result = {
            "zone": "Indiranagar",
            "pincode": "560001",
            "claimType": "RainLock",
            "alertTitle": "Test trigger",
            "hasActiveAlert": True,
            "autoClaimsCreated": 0,
            "source": "manual",
        }
        with patch(
            "backend.app.api.triggers.force_trigger_for_zone",
            new=AsyncMock(return_value=result),
        ):
            response = client.post(
                "/api/v1/triggers/force",
                json={
                    "zone": "560001",
                    "claimType": "RainLock",
                    "alertTitle": "Test trigger",
                    "alertDescription": "Administrative test trigger",
                    "confidence": 0.9,
                },
            )

        self.assertEqual(response.status_code, 401)

    def test_force_trigger_accepts_admin_authentication(self) -> None:
        client = self._client()
        client.app.dependency_overrides[get_admin_actor] = lambda: "admin"
        result = {
            "zone": "Indiranagar",
            "pincode": "560001",
            "claimType": "RainLock",
            "alertTitle": "Test trigger",
            "hasActiveAlert": True,
            "autoClaimsCreated": 0,
            "source": "manual",
        }
        with patch(
            "backend.app.api.triggers.force_trigger_for_zone",
            new=AsyncMock(return_value=result),
        ):
            response = client.post(
                "/api/v1/triggers/force",
                json={
                    "zone": "560001",
                    "claimType": "RainLock",
                    "alertTitle": "Test trigger",
                    "alertDescription": "Administrative test trigger",
                    "confidence": 0.9,
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["data"]["autoClaimsCreated"], 0)

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


class TriggerMonitorCoverageTests(unittest.IsolatedAsyncioTestCase):
    async def test_historical_risk_does_not_create_live_trigger_when_fallback_disabled(self) -> None:
        api_client = type(
            "ApiClient",
            (),
            {
                "get_rainfall_data": AsyncMock(return_value=None),
                "get_aqi_data": AsyncMock(return_value=None),
                "get_traffic_speed": AsyncMock(return_value=None),
                "get_heat_humidity_data": AsyncMock(return_value=None),
                "get_zone_disruption_news": AsyncMock(return_value=None),
            },
        )()
        zone = {
            "pincode": "560001",
            "name": "Indiranagar",
            "flood_risk_score": 0.95,
            "aqi_risk_score": 0.9,
            "traffic_congestion_score": 0.9,
            "latitude": 12.97,
            "longitude": 77.59,
        }
        with (
            patch("backend.app.services.trigger_monitor.get_api_client", return_value=api_client),
            patch.dict(
                "backend.app.core.config.settings.__dict__",
                {"allow_static_trigger_fallback": False},
            ),
        ):
            result = await _determine_trigger(zone)

        self.assertFalse(result["hasActiveAlert"])
        self.assertEqual(result["dataSource"], "none")

    async def test_force_trigger_skips_workers_without_active_coverage(self) -> None:
        worker = {
            "phone": "9999999999",
            "platform_name": "Blinkit",
            "zone_pincode": "560001",
            "plan_name": "Standard",
        }
        zone = {
            "name": "Indiranagar",
            "zone_risk_multiplier": 1.0,
            "latitude": 12.97,
            "longitude": 77.59,
        }
        create_claim = AsyncMock(
            return_value={
                "id": 17,
                "amount": 400.0,
                "created_at": "2026-08-15T00:00:00+00:00",
            }
        )
        with (
            patch("backend.app.services.trigger_monitor.resolve_zone", return_value=("560001", zone)),
            patch(
                "backend.app.services.trigger_monitor.list_workers_by_zone",
                new=AsyncMock(return_value=[worker]),
            ),
            patch(
                "backend.app.core.db.list_paid_premium_weeks_for_phone",
                new=AsyncMock(return_value=[]),
            ),
            patch(
                "backend.app.services.trigger_monitor.has_recent_auto_claim",
                new=AsyncMock(return_value=False),
            ),
            patch(
                "backend.app.services.trigger_monitor.calculate_zone_affinity_score",
                new=AsyncMock(return_value=0.95),
            ),
            patch(
                "backend.app.services.trigger_monitor._build_anomaly_features",
                new=AsyncMock(return_value={"zone_affinity_score": 0.95}),
            ),
            patch(
                "backend.app.services.trigger_monitor.score_claim",
                return_value={
                    "anomaly_score": 0.2,
                    "anomaly_threshold": -0.05,
                    "anomaly_flagged": False,
                    "anomaly_model_version": "iforest-v1",
                    "anomaly_features": {},
                    "anomaly_scored_at": "2026-08-15T00:00:00+00:00",
                    "llm_review_used": False,
                },
            ),
            patch("backend.app.services.trigger_monitor.create_claim", new=create_claim),
            patch(
                "backend.app.services.trigger_monitor.initiate_claim_payout",
                new=AsyncMock(return_value={"id": 91}),
            ),
        ):
            result = await force_trigger_for_zone(
                zone_key="560001",
                claim_type="RainLock",
                alert_title="Heavy rainfall",
                alert_description="Rainfall exceeded the threshold",
            )

        self.assertEqual(result["autoClaimsCreated"], 0)
        create_claim.assert_not_awaited()


if __name__ == "__main__":
    unittest.main()

