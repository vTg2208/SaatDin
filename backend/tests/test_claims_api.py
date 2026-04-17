from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.app.api.claims import router as claims_router
from backend.app.core.dependencies import get_current_worker


class ClaimsApiTests(unittest.TestCase):
    def _client(self) -> TestClient:
        app = FastAPI()
        app.include_router(claims_router, prefix="/api/v1/claims")
        app.dependency_overrides[get_current_worker] = lambda: {
            "phone": "9999999999",
            "zone_pincode": "560001",
            "zone_name": "Indiranagar",
            "name": "Worker",
            "platform_name": "Blinkit",
            "plan_name": "Standard",
        }
        return TestClient(app)

    def test_submit_claim_returns_review_record(self) -> None:
        client = self._client()
        claim_row = {
            "id": 17,
            "phone": "9999999999",
            "claim_type": "RainLock",
            "status": "in_review",
            "amount": 400.0,
            "description": "Flooded access road",
            "zone_pincode": "560001",
            "source": "manual",
            "created_at": "2026-04-12T12:00:00+00:00",
            "anomaly_score": -0.08,
            "anomaly_threshold": -0.05,
            "anomaly_flagged": True,
            "anomaly_model_version": "iforest-v1",
            "anomaly_features_json": {"gps_validation_status": "stable"},
            "anomaly_scored_at": "2026-04-12T12:00:01+00:00",
        }
        with (
            patch(
                "backend.app.api.claims._build_manual_claim_features",
                new=AsyncMock(return_value={"zone_affinity_score": 0.8}),
            ),
            patch(
                "backend.app.api.claims.score_claim",
                return_value={
                    "anomaly_score": -0.08,
                    "anomaly_threshold": -0.05,
                    "anomaly_flagged": True,
                    "anomaly_model_version": "iforest-v1",
                    "anomaly_features": {"gps_validation_status": "stable"},
                    "anomaly_scored_at": "2026-04-12T12:00:01+00:00",
                    "llm_review_used": False,
                    "llm_review_status": None,
                    "llm_provider": None,
                    "llm_model": None,
                    "llm_fallback_used": None,
                    "llm_decision_confidence": None,
                    "llm_decision_json": None,
                    "llm_attempts": None,
                    "llm_validation_error": None,
                    "llm_scored_at": None,
                },
            ),
            patch("backend.app.api.claims.create_claim", new=AsyncMock(return_value=claim_row)),
        ):
            response = client.post(
                "/api/v1/claims/submit",
                json={"claimType": "RainLock", "description": "Flooded access road"},
            )

        self.assertEqual(response.status_code, 201)
        payload = response.json()
        self.assertTrue(payload["success"])
        self.assertEqual(payload["data"]["status"], "in_review")
        self.assertEqual(payload["data"]["id"], "#C00017")

    def test_escalate_claim_rejects_wrong_owner(self) -> None:
        client = self._client()
        with patch(
            "backend.app.api.claims.get_claim",
            new=AsyncMock(return_value={"id": 5, "phone": "8888888888"}),
        ):
            response = client.post(
                "/api/v1/claims/5/escalate",
                json={"reason": "Trigger did not account for civic shutdown"},
            )

        self.assertEqual(response.status_code, 403)
        self.assertIn("does not belong", response.text)

    def test_escalate_claim_returns_escalation_record(self) -> None:
        client = self._client()
        with (
            patch(
                "backend.app.api.claims.get_claim",
                new=AsyncMock(return_value={"id": 5, "phone": "9999999999"}),
            ),
            patch(
                "backend.app.api.claims.escalate_claim",
                new=AsyncMock(
                    return_value={
                        "id": 9,
                        "claim_id": 5,
                        "phone": "9999999999",
                        "reason": "Trigger did not account for civic shutdown",
                        "status": "pending_review",
                        "created_at": "2026-04-12T12:00:00+00:00",
                    }
                ),
            ),
        ):
            response = client.post(
                "/api/v1/claims/5/escalate",
                json={"reason": "Trigger did not account for civic shutdown"},
            )

        self.assertEqual(response.status_code, 201)
        payload = response.json()
        self.assertTrue(payload["success"])
        self.assertEqual(payload["data"]["claimId"], 5)
        self.assertEqual(payload["data"]["status"], "pending_review")


if __name__ == "__main__":
    unittest.main()
