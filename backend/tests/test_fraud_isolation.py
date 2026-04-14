"""Tests for the fraud isolation scoring service."""
from __future__ import annotations

import unittest
from unittest.mock import patch

from backend.app.services.fraud_isolation import (
    normalize_features,
    score_claim,
    FEATURE_NAMES,
    DEFAULT_FEATURES,
)


class NormalizeFeaturesTests(unittest.TestCase):
    def test_returns_all_feature_names(self) -> None:
        result = normalize_features({})
        for name in FEATURE_NAMES:
            self.assertIn(name, result)

    def test_uses_defaults_for_missing_keys(self) -> None:
        result = normalize_features({})
        for name in FEATURE_NAMES:
            self.assertEqual(result[name], DEFAULT_FEATURES[name])

    def test_preserves_provided_values(self) -> None:
        features = {"zone_affinity_score": 0.9, "fraud_ring_size": 3.0}
        result = normalize_features(features)
        self.assertEqual(result["zone_affinity_score"], 0.9)
        self.assertEqual(result["fraud_ring_size"], 3.0)

    def test_coerces_booleans(self) -> None:
        features = {"is_manual_source": True, "is_auto_source": False}
        result = normalize_features(features)
        self.assertEqual(result["is_manual_source"], 1.0)
        self.assertEqual(result["is_auto_source"], 0.0)

    def test_handles_none_gracefully(self) -> None:
        features = {"zone_affinity_score": None}
        result = normalize_features(features)
        self.assertEqual(result["zone_affinity_score"], DEFAULT_FEATURES["zone_affinity_score"])

    def test_handles_nan_gracefully(self) -> None:
        features = {"zone_affinity_score": float("nan")}
        result = normalize_features(features)
        self.assertEqual(result["zone_affinity_score"], DEFAULT_FEATURES["zone_affinity_score"])


class ScoreClaimDisabledTests(unittest.TestCase):
    def test_disabled_scoring_returns_not_flagged(self) -> None:
        with patch("backend.app.services.fraud_isolation.settings") as mock_settings:
            mock_settings.fraud_scoring_enabled = False
            mock_settings.fraud_anomaly_threshold = -0.5
            mock_settings.fraud_metrics_log_every_n = 100
            result = score_claim({}, context={"phone": "9876543210", "claim_type": "RainLock", "source": "auto"})

        self.assertEqual(result["anomaly_score"], 0.0)
        self.assertFalse(result["anomaly_flagged"])
        self.assertEqual(result["anomaly_model_version"], "disabled")
        self.assertFalse(result["llm_review_used"])


class ScoreClaimFailOpenTests(unittest.TestCase):
    def test_fail_open_when_model_unavailable(self) -> None:
        with patch("backend.app.services.fraud_isolation.settings") as mock_settings:
            mock_settings.fraud_scoring_enabled = True
            mock_settings.fraud_fail_open = True
            mock_settings.fraud_anomaly_threshold = -0.5
            mock_settings.fraud_metrics_log_every_n = 100
            mock_settings.fraud_model_file_path = type("P", (), {"exists": lambda s: False, "stem": "missing"})()
            result = score_claim({}, context={"phone": "test", "source": "auto", "claim_type": "RainLock"})

        self.assertFalse(result["anomaly_flagged"])
        self.assertIn("fail-open", result["anomaly_model_version"])


if __name__ == "__main__":
    unittest.main()
