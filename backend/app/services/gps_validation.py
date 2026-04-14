from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Mapping, Optional

from ..core.db import get_worker_location_signal


def _coerce_float(value: Any, default: float) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return default
    if parsed != parsed:
        return default
    return parsed


def _parse_iso_datetime(value: Any) -> Optional[datetime]:
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc)
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


async def evaluate_worker_gps_signal(*, phone: str) -> Dict[str, Any]:
    signal = await get_worker_location_signal(phone)
    if signal is None:
        return {
            "status": "missing",
            "confidence": 0.5,
            "reason": "gps_signal_not_found",
            "signal_present": False,
            "signal_received_at": None,
            "signal_age_minutes": None,
            "variance_meters": 0.0,
            "jump_ratio": 0.0,
        }

    received_at = _parse_iso_datetime(signal.get("received_at"))
    age_minutes = None
    if received_at is not None:
        age_minutes = max(0.0, (datetime.now(timezone.utc) - received_at).total_seconds() / 60.0)

    confidence = max(0.0, min(1.0, _coerce_float(signal.get("gps_variance_score"), 0.5)))
    variance_meters = _coerce_float(signal.get("gps_variance_meters"), 0.0)
    jump_ratio = _coerce_float(signal.get("gps_jump_ratio"), 0.0)

    if confidence >= 0.75:
        status = "stable"
        reason = "gps_variance_stable"
    elif confidence >= 0.45:
        status = "mixed"
        reason = "gps_variance_mixed"
    else:
        status = "erratic"
        reason = "gps_variance_erratic"

    return {
        "status": status,
        "confidence": round(confidence, 3),
        "reason": reason,
        "signal_present": True,
        "signal_received_at": signal.get("received_at"),
        "signal_age_minutes": round(age_minutes, 3) if age_minutes is not None else None,
        "variance_meters": round(variance_meters, 3),
        "jump_ratio": round(jump_ratio, 3),
    }


def gps_features_from_validation(validation: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        "gps_variance_score": max(0.0, min(1.0, _coerce_float(validation.get("confidence"), 0.5))),
        "gps_validation_status": str(validation.get("status", "missing")),
        "gps_validation_reason": str(validation.get("reason", "gps_signal_not_found")),
        "gps_signal_present": 1.0 if bool(validation.get("signal_present")) else 0.0,
        "gps_signal_age_minutes": _coerce_float(validation.get("signal_age_minutes"), 0.0),
        "gps_signal_received_at": validation.get("signal_received_at"),
        "gps_variance_meters": _coerce_float(validation.get("variance_meters"), 0.0),
        "gps_jump_ratio": _coerce_float(validation.get("jump_ratio"), 0.0),
    }
