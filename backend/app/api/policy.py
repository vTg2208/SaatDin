from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException

from ..core.db import list_claims_for_phone, set_pending_worker_plan, total_settled_amount_for_phone
from ..core.dependencies import get_current_worker
from ..core.zone_cache import resolve_zone
from ..models.platform import Platform
from ..models.schemas import ApiResponse, PolicyOut, PolicyUpdateRequest
from ..services.premium import build_plans

router = APIRouter(tags=["policy"])
logger = logging.getLogger(__name__)


def _next_week_start_utc(now: datetime) -> datetime:
    days_until_next_monday = (7 - now.weekday()) % 7
    if days_until_next_monday == 0:
        days_until_next_monday = 7
    next_monday = (now + timedelta(days=days_until_next_monday)).replace(
        hour=0,
        minute=0,
        second=0,
        microsecond=0,
    )
    return next_monday


def _clean_streak_weeks_from_claim_rows(claim_rows: list[dict]) -> int:
    if not claim_rows:
        return 6

    today = datetime.now(timezone.utc).date()
    claim_dates: list[datetime.date] = []
    for row in claim_rows:
        raw = row.get("created_at")
        if raw is None:
            continue
        try:
            parsed = raw if isinstance(raw, datetime) else datetime.fromisoformat(str(raw))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            claim_dates.append(parsed.astimezone(timezone.utc).date())
        except (TypeError, ValueError):
            continue

    if not claim_dates:
        return 6

    streak = 0
    for week_offset in range(12):
        week_start = today - timedelta(days=today.weekday() + (week_offset * 7))
        week_end = week_start + timedelta(days=7)
        has_claim = any((not d < week_start) and d < week_end for d in claim_dates)
        if has_claim:
            break
        streak += 1
    return streak


def _loyalty_discount_percent(clean_streak_weeks: int) -> float:
    if clean_streak_weeks >= 6:
        return 10.0
    if clean_streak_weeks >= 4:
        return 5.0
    return 0.0


def _build_policy(worker: dict, settled_total: float) -> PolicyOut:
    try:
        platform = Platform.from_input(str(worker.get("platform_name") or "swiggy_instamart"))
    except HTTPException:
        platform = Platform.swiggy_instamart

    zone_key = str(worker.get("zone_pincode") or worker.get("zone_name") or "560001")
    try:
        pincode, zone_data = resolve_zone(zone_key)
    except HTTPException:
        pincode, zone_data = resolve_zone("560001")

    plans = build_plans(float(zone_data.get("zone_risk_multiplier", 1.0)), platform, zone_data=zone_data)
    selected = next((plan for plan in plans if plan.name.lower() == str(worker.get("plan_name") or "").lower()), None)
    if not selected:
        selected = plans[1]

    now = datetime.now(timezone.utc)
    next_billing = _next_week_start_utc(now).date().isoformat()
    pending_effective_at = worker.get("pending_plan_effective_at")
    pending_effective_date = None
    if pending_effective_at:
        pending_effective_date = str(pending_effective_at)[:10]

    return PolicyOut(
        status="active",
        plan=selected.name,
        pendingPlan=worker.get("pending_plan_name"),
        pendingEffectiveDate=pending_effective_date,
        zone=str(worker.get("zone_name") or zone_data.get("name") or "Unknown"),
        zonePincode=str(worker.get("zone_pincode") or pincode),
        weeklyPremium=selected.weeklyPremium,
        earningsProtected=round(settled_total, 2),
        parametricCoverageOn=True,
        perTriggerPayout=selected.perTriggerPayout,
        maxDaysPerWeek=selected.maxDaysPerWeek,
        nextBillingDate=next_billing,
    )


@router.get("/me", response_model=ApiResponse)
async def get_my_policy(worker: dict = Depends(get_current_worker)) -> ApiResponse:
    settled_total = await total_settled_amount_for_phone(str(worker["phone"]))
    claim_rows = await list_claims_for_phone(str(worker["phone"]))
    clean_streak_weeks = _clean_streak_weeks_from_claim_rows(claim_rows)
    loyalty_discount_percent = _loyalty_discount_percent(clean_streak_weeks)
    policy = _build_policy(worker, settled_total)
    policy.cleanStreakWeeks = clean_streak_weeks
    policy.loyaltyDiscountPercent = loyalty_discount_percent
    logger.info("policy_requested phone=%s", worker["phone"])
    return ApiResponse(success=True, data=policy)


@router.put("/plan", response_model=ApiResponse)
async def update_policy_plan(payload: PolicyUpdateRequest, worker: dict = Depends(get_current_worker)) -> ApiResponse:
    platform = Platform.from_input(str(worker["platform_name"]))
    _, zone_data = resolve_zone(str(worker["zone_pincode"]))
    plans = build_plans(float(zone_data.get("zone_risk_multiplier", 1.0)), platform, zone_data=zone_data)
    selected = next((plan for plan in plans if plan.name.lower() == payload.planName.strip().lower()), None)
    if not selected:
        raise HTTPException(status_code=400, detail=f"Unknown plan: {payload.planName}")

    current_plan = str(worker["plan_name"]).strip().lower()
    if selected.name.strip().lower() == current_plan:
        settled_total = await total_settled_amount_for_phone(str(worker["phone"]))
        claim_rows = await list_claims_for_phone(str(worker["phone"]))
        clean_streak_weeks = _clean_streak_weeks_from_claim_rows(claim_rows)
        loyalty_discount_percent = _loyalty_discount_percent(clean_streak_weeks)
        policy = _build_policy(worker, settled_total)
        policy.cleanStreakWeeks = clean_streak_weeks
        policy.loyaltyDiscountPercent = loyalty_discount_percent
        return ApiResponse(success=True, data=policy, message="Selected plan is already active")

    next_week_effective_at = _next_week_start_utc(datetime.now(timezone.utc))
    await set_pending_worker_plan(str(worker["phone"]), selected.name, next_week_effective_at)
    worker["pending_plan_name"] = selected.name
    worker["pending_plan_effective_at"] = next_week_effective_at.isoformat()

    settled_total = await total_settled_amount_for_phone(str(worker["phone"]))
    claim_rows = await list_claims_for_phone(str(worker["phone"]))
    clean_streak_weeks = _clean_streak_weeks_from_claim_rows(claim_rows)
    loyalty_discount_percent = _loyalty_discount_percent(clean_streak_weeks)
    policy = _build_policy(worker, settled_total)
    policy.cleanStreakWeeks = clean_streak_weeks
    policy.loyaltyDiscountPercent = loyalty_discount_percent
    logger.info(
        "policy_change_queued phone=%s current_plan=%s pending_plan=%s effective_at=%s",
        worker["phone"],
        worker["plan_name"],
        selected.name,
        next_week_effective_at.isoformat(),
    )
    return ApiResponse(success=True, data=policy, message="Plan change queued for next week")
