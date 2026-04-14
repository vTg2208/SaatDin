from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, patch

from backend.app.services import fraud_isolation
from backend.app.services.gps_validation import evaluate_worker_gps_signal, gps_features_from_validation


class _StubIsolationModel:
    def __init__(self, score: float) -> None:
        self._score = score

    def decision_function(self, _feature_vector):
        return [self._score]


class GpsValidationTests(unittest.IsolatedAsyncioTestCase):
    async def test_missing_gps_signal_is_neutral(self) -> None:
        with patch(
            "backend.app.services.gps_validation.get_worker_location_signal",
            new=AsyncMock(return_value=None),
        ):
            result = await evaluate_worker_gps_signal(phone="9999999999")

        self.assertEqual(result["status"], "missing")
        self.assertEqual(result["confidence"], 0.5)
        self.assertFalse(result["signal_present"])

    async def test_stable_gps_signal_surfaces_variance_features(self) -> None:
        with patch(
            "backend.app.services.gps_validation.get_worker_location_signal",
            new=AsyncMock(
                return_value={
                    "received_at": "2026-04-12T12:00:00+00:00",
                    "gps_variance_score": 0.82,
                    "gps_variance_meters": 24.0,
                    "gps_jump_ratio": 0.0,
                }
            ),
        ):
            result = await evaluate_worker_gps_signal(phone="9999999999")

        self.assertEqual(result["status"], "stable")
        self.assertGreater(result["confidence"], 0.75)
        self.assertEqual(result["variance_meters"], 24.0)

        features = gps_features_from_validation(result)
        self.assertEqual(features["gps_validation_status"], "stable")
        self.assertGreater(features["gps_variance_score"], 0.75)

    async def test_gps_adjustment_penalizes_erratic_spoof_pattern(self) -> None:
        features = {
            "zone_affinity_score": 0.8,
            "fraud_ring_size": 0.0,
            "recent_claims_24h": 0.0,
            "claim_amount": 320.0,
            "trigger_confidence": 0.6,
            "is_manual_source": 1.0,
            "is_auto_source": 0.0,
            "flood_risk_score": 0.5,
            "aqi_risk_score": 0.4,
            "traffic_congestion_score": 0.4,
            "gps_validation_status": "erratic",
            "gps_validation_reason": "gps_variance_erratic",
            "gps_variance_score": 0.2,
            "gps_signal_present": 1.0,
            "gps_signal_age_minutes": 2.0,
            "gps_variance_meters": 6400.0,
            "gps_jump_ratio": 0.75,
        }
        with (
            patch.object(fraud_isolation, "_model", _StubIsolationModel(-0.04)),
            patch.object(fraud_isolation, "_model_version", "iforest-v1"),
            patch.object(fraud_isolation.settings, "fraud_llm_fallback_enabled", False),
        ):
            result = fraud_isolation.score_claim(
                features,
                context={"phone": "9999999999", "claim_type": "RainLock"},
            )

        self.assertTrue(result["anomaly_flagged"])
        self.assertLess(float(result["anomaly_features"]["gps_score_adjustment"]), 0.0)
        self.assertEqual(result["anomaly_features"]["gps_validation_status"], "erratic")


if __name__ == "__main__":
    unittest.main()
