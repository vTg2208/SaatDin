from __future__ import annotations

from typing import Any, Dict, Tuple

from fastapi import HTTPException

from .db import list_zone_risk_rows
from ..models.platform import Platform
from ..models.schemas import ZoneOut

_ZONE_MAP: Dict[str, Dict[str, Any]] = {}
_ZONE_NAME_INDEX: Dict[str, str] = {}


async def refresh_zone_cache() -> Dict[str, Dict[str, Any]]:
    global _ZONE_MAP
    global _ZONE_NAME_INDEX

    rows = await list_zone_risk_rows()
    zone_map: Dict[str, Dict[str, Any]] = {}
    for row in rows:
        pincode = str(row.get("pincode", "")).strip()
        zone_json = row.get("zone_json")
        if not pincode or not isinstance(zone_json, dict):
            continue
        zone_map[pincode] = zone_json
    if not zone_map:
        raise RuntimeError("zone_risk table has no usable rows")

    _ZONE_MAP = zone_map
    _ZONE_NAME_INDEX = {
        str(zone.get("name", "")).strip().lower(): pincode for pincode, zone in zone_map.items()
    }
    return _ZONE_MAP


def load_zone_map() -> Dict[str, Dict[str, Any]]:
    if not _ZONE_MAP:
        raise RuntimeError("zone cache not loaded; call refresh_zone_cache() during startup")
    return _ZONE_MAP


def zone_name_index() -> Dict[str, str]:
    if not _ZONE_NAME_INDEX:
        _ = load_zone_map()
    return _ZONE_NAME_INDEX


def clear_zone_cache() -> None:
    global _ZONE_MAP
    global _ZONE_NAME_INDEX
    _ZONE_MAP = {}
    _ZONE_NAME_INDEX = {}


def resolve_zone(zone_key: str) -> Tuple[str, Dict[str, Any]]:
    zones = load_zone_map()
    stripped = zone_key.strip()
    if stripped in zones:
        return stripped, zones[stripped]

    by_name = zone_name_index().get(stripped.lower())
    if by_name and by_name in zones:
        return by_name, zones[by_name]

    raise HTTPException(status_code=404, detail=f"Unknown zone: {zone_key}")


def supports_platform(zone: Dict[str, Any], platform: Platform) -> bool:
    stores = zone.get("dark_stores", {})
    if platform is Platform.blinkit:
        return stores.get("Blinkit") is True
    if platform is Platform.zepto:
        return stores.get("Zepto") is True
    if platform is Platform.swiggy_instamart:
        return stores.get("Swiggy_Instamart") is True
    return False


def to_zone_out(pincode: str, zone: Dict[str, Any]) -> ZoneOut:
    stores = zone.get("dark_stores", {})
    return ZoneOut(
        pincode=pincode,
        name=zone.get("name", ""),
        zoneRiskMultiplier=float(zone.get("zone_risk_multiplier", 1.0)),
        riskTier=str(zone.get("risk_tier", "MEDIUM")),
        customRainLockThresholdMm3hr=int(zone.get("custom_rainlock_threshold_mm_3hr", 35)),
        supports={
            "blinkit": stores.get("Blinkit") is True,
            "zepto": stores.get("Zepto") is True,
            "swiggyInstamart": stores.get("Swiggy_Instamart") is True,
        },
    )
