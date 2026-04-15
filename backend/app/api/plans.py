from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Query

from ..core.db import get_worker
from ..core.dependencies import get_current_phone
from ..core.zone_cache import resolve_zone, supports_platform
from ..models.platform import Platform
from ..models.schemas import ApiResponse
from ..services.premium import build_plans

router = APIRouter(tags=["plans"])
logger = logging.getLogger(__name__)


@router.get("", response_model=ApiResponse)
async def get_plans(
    zone: str = Query(...),
    platform: str = Query(...),
    phone: str = Depends(get_current_phone),
) -> ApiResponse:
    worker = await get_worker(phone)

    try:
        _, zone_data = resolve_zone(zone)
    except HTTPException:
        if not worker:
            raise

        fallback_candidates = [
            str(worker.get("zone_pincode") or "").strip(),
            str(worker.get("zone_name") or "").strip(),
        ]
        resolved_fallback = ""
        zone_data = None
        for candidate in fallback_candidates:
            if not candidate:
                continue
            try:
                _, zone_data = resolve_zone(candidate)
                resolved_fallback = candidate
                break
            except HTTPException:
                continue

        if zone_data is None:
            raise

        logger.info(
            "plans_zone_fallback_applied phone=%s requested_zone=%s fallback_zone=%s",
            phone,
            zone,
            resolved_fallback,
        )

    try:
        normalized = Platform.from_input(platform)
    except HTTPException:
        if not worker:
            raise
        worker_platform_raw = str(worker.get("platform_name") or "").strip()
        if not worker_platform_raw:
            raise
        normalized = Platform.from_input(worker_platform_raw)
        logger.info(
            "plans_platform_fallback_applied phone=%s requested_platform=%s fallback_platform=%s",
            phone,
            platform,
            worker_platform_raw,
        )

    if not supports_platform(zone_data, normalized):
        if worker:
            worker_platform_raw = str(worker.get("platform_name") or "").strip()
            if worker_platform_raw:
                worker_platform = Platform.from_input(worker_platform_raw)
                if supports_platform(zone_data, worker_platform):
                    logger.info(
                        "plans_platform_support_fallback_applied phone=%s requested_platform=%s fallback_platform=%s",
                        phone,
                        platform,
                        worker_platform_raw,
                    )
                    normalized = worker_platform
                else:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Platform {platform} not supported in resolved zone",
                    )
            else:
                raise HTTPException(status_code=400, detail=f"Platform {platform} not supported in resolved zone")
        else:
            raise HTTPException(status_code=400, detail=f"Platform {platform} not supported in resolved zone")

    zone_multiplier = float(zone_data.get("zone_risk_multiplier", 1.0))
    return ApiResponse(success=True, data=build_plans(zone_multiplier, normalized, zone_data=zone_data))
