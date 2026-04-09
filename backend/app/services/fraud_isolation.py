from __future__ import annotations

import json
import logging
import math
from collections import deque
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Mapping, Optional

from ..core.config import settings

try:
    from joblib import load
except ImportError:
    load = None  # type: ignore

try:
    import numpy as np
except ImportError:
    np = None  # type: ignore

logger = logging.getLogger(__name__)

FEATURE_NAMES: tuple[str, ...] = (
    "zone_affinity_score",
    "fraud_ring_size",
    "recent_claims_24h",
    "claim_amount",
    "trigger_confidence",
    "is_manual_source",
    "is_auto_source",
    "flood_risk_score",
    "aqi_risk_score",
    "traffic_congestion_score",
)

DEFAULT_FEATURES: Dict[str, float] = {
    "zone_affinity_score": 0.5,
    "fraud_ring_size": 0.0,
    "recent_claims_24h": 0.0,
    "claim_amount": 250.0,
    "trigger_confidence": 0.55,
    "is_manual_source": 0.0,
    "is_auto_source": 1.0,
    "flood_risk_score": 0.5,
    "aqi_risk_score": 0.5,
    "traffic_congestion_score": 0.5,
}

_model: Any = None
_model_version = "uninitialized"
_metrics_total = 0
_metrics_flagged = 0
_metrics_errors = 0
_metrics_scores: deque[float] = deque(maxlen=512)


def _metadata_path(model_path: Path) -> Path:
    return model_path.with_suffix(".json")


def _load_metadata(model_path: Path) -> Dict[str, Any]:
    metadata_path = _metadata_path(model_path)
    if not metadata_path.exists():
        return {}
    try:
        return json.loads(metadata_path.read_text(encoding="utf-8"))
    except Exception as exc:
        logger.warning("fraud_model_metadata_read_failed path=%s error=%s", metadata_path, exc)
        return {}


def _coerce_feature_value(value: Any, default: float) -> float:
    if value is None:
        return default
    if isinstance(value, bool):
        return 1.0 if value else 0.0
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return default
    if math.isnan(parsed) or math.isinf(parsed):
        return default
    return parsed


def normalize_features(features: Mapping[str, Any]) -> Dict[str, float]:
    normalized: Dict[str, float] = {}
    for name in FEATURE_NAMES:
        normalized[name] = _coerce_feature_value(features.get(name), DEFAULT_FEATURES[name])
    return normalized


def initialize_fraud_model() -> None:
    global _model
    global _model_version

    if not settings.fraud_scoring_enabled:
        _model = None
        _model_version = "disabled"
        logger.info("fraud_scoring_disabled")
        return

    if load is None:
        _model = None
        _model_version = "missing-joblib"
        logger.warning("fraud_model_unavailable reason=joblib_not_installed")
        return

    model_path = settings.fraud_model_file_path
    if not model_path.exists():
        _model = None
        _model_version = "missing-artifact"
        logger.warning("fraud_model_unavailable reason=artifact_missing path=%s", model_path)
        return

    try:
        loaded_model = load(model_path)
        if not hasattr(loaded_model, "decision_function"):
            raise TypeError("Loaded artifact does not expose decision_function")
        _model = loaded_model
        metadata = _load_metadata(model_path)
        _model_version = str(metadata.get("version") or model_path.stem)
        logger.info(
            "fraud_model_loaded path=%s version=%s feature_count=%s",
            model_path,
            _model_version,
            len(FEATURE_NAMES),
        )
    except Exception as exc:
        _model = None
        _model_version = "load-failed"
        logger.exception("fraud_model_load_failed path=%s error=%s", model_path, exc)


def _record_metrics(score: float, flagged: bool, errored: bool) -> None:
    global _metrics_total
    global _metrics_flagged
    global _metrics_errors

    _metrics_total += 1
    if flagged:
        _metrics_flagged += 1
    if errored:
        _metrics_errors += 1
    _metrics_scores.append(score)

    if _metrics_total <= 0:
        return

    log_every = max(1, int(settings.fraud_metrics_log_every_n))
    if _metrics_total % log_every != 0:
        return

    sorted_scores = sorted(_metrics_scores)
    p95_index = int((len(sorted_scores) - 1) * 0.95) if sorted_scores else 0
    p95_score = sorted_scores[p95_index] if sorted_scores else 0.0
    flagged_rate = _metrics_flagged / _metrics_total
    logger.info(
        "fraud_metrics window=%s total=%s flagged=%s flagged_rate=%.4f p95_score=%.6f errors=%s model_version=%s",
        len(_metrics_scores),
        _metrics_total,
        _metrics_flagged,
        flagged_rate,
        p95_score,
        _metrics_errors,
        _model_version,
    )


def _log_score_event(result: Dict[str, Any], context: Mapping[str, Any], mode: str) -> None:
    logger.info(
        "fraud_score_evaluated mode=%s model_version=%s score=%.6f threshold=%.6f flagged=%s claim_type=%s source=%s phone=%s",
        mode,
        result["anomaly_model_version"],
        float(result["anomaly_score"]),
        float(result["anomaly_threshold"]),
        bool(result["anomaly_flagged"]),
        str(context.get("claim_type", "unknown")),
        str(context.get("source", "unknown")),
        str(context.get("phone", "unknown")),
    )


def score_claim(
    features: Mapping[str, Any],
    *,
    context: Optional[Mapping[str, Any]] = None,
) -> Dict[str, Any]:
    threshold = float(settings.fraud_anomaly_threshold)
    normalized = normalize_features(features)
    scored_at = datetime.now(timezone.utc).isoformat()
    event_context = context or {}

    if not settings.fraud_scoring_enabled:
        result = {
            "anomaly_score": 0.0,
            "anomaly_threshold": threshold,
            "anomaly_flagged": False,
            "anomaly_model_version": "disabled",
            "anomaly_features": normalized,
            "anomaly_scored_at": scored_at,
        }
        _record_metrics(0.0, False, False)
        _log_score_event(result, event_context, mode="disabled")
        return result

    if _model is None:
        initialize_fraud_model()

    if _model is None:
        if settings.fraud_fail_open:
            result = {
                "anomaly_score": 0.0,
                "anomaly_threshold": threshold,
                "anomaly_flagged": False,
                "anomaly_model_version": f"{_model_version}:fail-open",
                "anomaly_features": normalized,
                "anomaly_scored_at": scored_at,
            }
            _record_metrics(0.0, False, True)
            _log_score_event(result, event_context, mode="fail-open")
            return result
        raise RuntimeError("Fraud model unavailable and FRAUD_FAIL_OPEN is false")

    if np is None:
        if settings.fraud_fail_open:
            result = {
                "anomaly_score": 0.0,
                "anomaly_threshold": threshold,
                "anomaly_flagged": False,
                "anomaly_model_version": f"{_model_version}:missing-numpy",
                "anomaly_features": normalized,
                "anomaly_scored_at": scored_at,
            }
            _record_metrics(0.0, False, True)
            _log_score_event(result, event_context, mode="fail-open")
            return result
        raise RuntimeError("NumPy unavailable and FRAUD_FAIL_OPEN is false")

    try:
        feature_vector = np.array([[normalized[name] for name in FEATURE_NAMES]], dtype=float)
        raw_score = float(_model.decision_function(feature_vector)[0])
        flagged = raw_score < threshold
        result = {
            "anomaly_score": round(raw_score, 6),
            "anomaly_threshold": threshold,
            "anomaly_flagged": flagged,
            "anomaly_model_version": _model_version,
            "anomaly_features": normalized,
            "anomaly_scored_at": scored_at,
        }
        _record_metrics(raw_score, flagged, False)
        _log_score_event(result, event_context, mode="model")
        return result
    except Exception as exc:
        if settings.fraud_fail_open:
            logger.exception("fraud_scoring_failed mode=fail-open error=%s", exc)
            result = {
                "anomaly_score": 0.0,
                "anomaly_threshold": threshold,
                "anomaly_flagged": False,
                "anomaly_model_version": f"{_model_version}:score-failed",
                "anomaly_features": normalized,
                "anomaly_scored_at": scored_at,
            }
            _record_metrics(0.0, False, True)
            _log_score_event(result, event_context, mode="fail-open")
            return result
        raise
