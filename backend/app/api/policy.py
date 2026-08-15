from __future__ import annotations

import logging
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status

from ..core.config import settings
from ..core.db import (
    _coerce_dt,
    list_paid_premium_weeks_for_phone,
    set_pending_worker_plan,
    total_settled_amount_for_phone,
    upsert_premium_payment_week,
)
from ..core.dependencies import get_current_worker
from ..core.zone_cache import resolve_zone
from ..models.platform import Platform
from ..models.schemas import (
    ApiResponse,
    PaymentOrderCreateRequest,
    PaymentOrderOut,
    PolicyOut,
    PolicyUpdateRequest,
    PremiumPaymentRecordRequest,
)
from ..services.billing_client import (
    BillingServiceError,
    PaymentOrderCreate,
    PaymentOrderView,
    get_billing_client,
)
from ..services.premium import build_plans

router = APIRouter(tags=["policy"])
logger = logging.getLogger(__name__)


def _payment_order_out(order: PaymentOrderView) -> PaymentOrderOut:
    return PaymentOrderOut(
        orderId=str(order.order_id),
        status=order.status,
        provider=order.provider,
        amount=order.amount,
        currency=order.currency,
        coverageWeekStart=order.coverage_week_start,
        expiresAt=order.expires_at,
        checkoutData=order.checkout_data,
    )


def _billing_http_error(exc: BillingServiceError) -> HTTPException:
    if exc.status_code in {400, 404, 409}:
        return HTTPException(status_code=exc.status_code, detail=str(exc))
    return HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Billing service unavailable")


def _next_week_start_utc(now: datetime) -> datetime:
    current = now.astimezone(timezone.utc)
    current_cycle_start = current.replace(hour=0, minute=1, second=0, microsecond=0) - timedelta(days=current.weekday())
    if current < current_cycle_start:
        return current_cycle_start

    days_until_next_monday = 7 - current.weekday()
    if days_until_next_monday <= 0:
        days_until_next_monday = 7
    return (current + timedelta(days=days_until_next_monday)).replace(
        hour=0,
        minute=1,
        second=0,
        microsecond=0,
    )


def _current_cycle_start_utc(now: datetime | None = None) -> datetime:
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    return current.replace(hour=0, minute=1, second=0, microsecond=0) - timedelta(days=current.weekday())


def _current_week_start_utc(today: date | None = None) -> date:
    today = today or datetime.now(timezone.utc).date()
    return today - timedelta(days=today.weekday())


def _paid_week_starts(payment_rows: list[dict]) -> set[date]:
    paid_weeks: set[date] = set()
    for row in payment_rows:
        raw = row.get("week_start_date")
        if raw is None:
            continue
        try:
            if isinstance(raw, date):
                paid_weeks.add(raw)
                continue
            parsed = date.fromisoformat(str(raw)[:10])
            paid_weeks.add(parsed)
        except (TypeError, ValueError):
            continue
    return paid_weeks


def _clean_streak_weeks_from_paid_rows(payment_rows: list[dict]) -> int:
    paid_weeks = _paid_week_starts(payment_rows)
    if not paid_weeks:
        return 0

    cursor = _current_week_start_utc()
    streak = 0
    for _ in range(104):
        if cursor not in paid_weeks:
            break
        streak += 1
        cursor -= timedelta(days=7)
    return streak


def _effective_cycle_week(clean_streak_weeks: int) -> int:
    if clean_streak_weeks <= 0:
        return 0
    # 9-week loyalty cycle: 6-week build-up + 3-week carry-forward at max tier.
    return ((clean_streak_weeks - 1) % 9) + 1


def _loyalty_discount_percent(clean_streak_weeks: int) -> float:
    cycle_week = _effective_cycle_week(clean_streak_weeks)
    if cycle_week >= 6:
        return 10.0
    if cycle_week >= 4:
        return 5.0
    return 0.0


def _coerce_week_start(raw_week_start: str | None) -> date:
    minimum_week_start = _next_week_start_utc(datetime.now(timezone.utc)).date()
    if not raw_week_start:
        logger.info("policy_week_start_fallback_applied reason=missing_input week_start=%s", minimum_week_start.isoformat())
        return minimum_week_start
    try:
        parsed = date.fromisoformat(str(raw_week_start)[:10])
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid weekStartDate") from exc
    normalized = parsed - timedelta(days=parsed.weekday())
    if normalized < minimum_week_start:
        logger.info(
            "policy_week_start_fallback_applied reason=past_cycle requested=%s normalized=%s fallback=%s",
            str(raw_week_start),
            normalized.isoformat(),
            minimum_week_start.isoformat(),
        )
        return minimum_week_start
    return normalized


def _apply_loyalty_discount(weekly_premium: int, loyalty_discount_percent: float) -> int:
    ratio = max(0.0, min(100.0, float(loyalty_discount_percent))) / 100.0
    discounted = float(weekly_premium) * (1.0 - ratio)
    return max(0, int(round(discounted)))


async def _authoritative_payment_rows(phone: str) -> list[dict]:
    if not settings.billing_service_enabled:
        return await list_paid_premium_weeks_for_phone(phone)

    client = get_billing_client()
    today = datetime.now(timezone.utc).date()
    current_week = _current_week_start_utc(today)
    next_week = current_week + timedelta(days=7)
    rows: list[dict] = []
    if await client.has_active_coverage(phone, today):
        rows.append({"week_start_date": current_week})
    if await client.has_active_coverage(phone, next_week):
        rows.append({"week_start_date": next_week})
    return rows


def _plan_name_for_coverage_week(worker: dict, coverage_week_start: date) -> str:
    pending_name = str(worker.get("pending_plan_name") or "").strip()
    pending_effective_at = _coerce_dt(worker.get("pending_plan_effective_at"))
    if pending_name and pending_effective_at and pending_effective_at.date() <= coverage_week_start:
        return pending_name
    return str(worker.get("plan_name") or "")


def _policy_cycle_context(worker: dict, now: datetime, paid_weeks: set[date]) -> tuple[str, date, date, date, int]:
    pending_effective_at = _coerce_dt(worker.get("pending_plan_effective_at"))
    current_cycle_start = _current_cycle_start_utc(now).date()

    future_candidates: list[date] = []
    if pending_effective_at is not None and pending_effective_at > now:
        future_candidates.append(pending_effective_at.date())

    future_paid_weeks = sorted(week for week in paid_weeks if week > current_cycle_start)
    if future_paid_weeks:
        future_candidates.extend(future_paid_weeks)

    if future_candidates:
        cycle_start_date = min(future_candidates)
        cycle_end_date = cycle_start_date + timedelta(days=6)
        next_billing_date = cycle_start_date
        days_left = max(0, (cycle_start_date - now.date()).days)
        return "scheduled", cycle_start_date, cycle_end_date, next_billing_date, days_left

    cycle_start_date = current_cycle_start
    cycle_end_date = cycle_start_date + timedelta(days=6)
    next_billing_date = cycle_start_date + timedelta(days=7)
    days_left = max(0, (cycle_end_date - now.date()).days)
    return "current", cycle_start_date, cycle_end_date, next_billing_date, days_left



def _build_policy(worker: dict, settled_total: float, payment_rows: list[dict]) -> PolicyOut:
    try:
        platform = Platform.from_input(str(worker.get("platform_name") or "swiggy_instamart"))
    except HTTPException as exc:
        logger.warning(
            "policy_platform_fallback_applied phone=%s raw_platform=%s fallback_platform=%s reason=%s",
            str(worker.get("phone") or "unknown"),
            str(worker.get("platform_name") or ""),
            Platform.swiggy_instamart.value,
            str(exc.detail) if hasattr(exc, "detail") else str(exc),
        )
        platform = Platform.swiggy_instamart

    zone_key = str(worker.get("zone_pincode") or worker.get("zone_name") or "560001")
    try:
        pincode, zone_data = resolve_zone(zone_key)
    except HTTPException as exc:
        logger.warning(
            "policy_zone_fallback_applied phone=%s requested_zone=%s fallback_zone=%s reason=%s",
            str(worker.get("phone") or "unknown"),
            zone_key,
            "560001",
            str(exc.detail) if hasattr(exc, "detail") else str(exc),
        )
        pincode, zone_data = resolve_zone("560001")

    plans = build_plans(float(zone_data.get("zone_risk_multiplier", 1.0)), platform, zone_data=zone_data)
    selected = next((plan for plan in plans if plan.name.lower() == str(worker.get("plan_name") or "").lower()), None)
    if not selected:
        logger.warning(
            "policy_plan_fallback_applied phone=%s requested_plan=%s fallback_plan=%s",
            str(worker.get("phone") or "unknown"),
            str(worker.get("plan_name") or ""),
            plans[1].name,
        )
        selected = plans[1]

    now = datetime.now(timezone.utc)
    paid_weeks = _paid_week_starts(payment_rows)
    cycle_state, cycle_start_date, cycle_end_date, next_billing_date, days_left = _policy_cycle_context(
        worker,
        now,
        paid_weeks,
    )
    paid_for_cycle = cycle_start_date in paid_weeks

    if cycle_state == "scheduled":
        status = "scheduled"
        amount_paid_this_week = 0.0
    else:
        status = "active" if paid_for_cycle else "inactive"
        amount_paid_this_week = float(selected.weeklyPremium) if paid_for_cycle else 0.0

    pending_effective_at = worker.get("pending_plan_effective_at")
    pending_effective_date = None
    if pending_effective_at:
        pending_effective_date = str(pending_effective_at)[:10]

    return PolicyOut(
        status=status,
        plan=selected.name,
        pendingPlan=worker.get("pending_plan_name"),
        pendingEffectiveDate=pending_effective_date,
        zone=str(worker.get("zone_name") or zone_data.get("name") or "Unknown"),
        zonePincode=str(worker.get("zone_pincode") or pincode),
        weeklyPremium=selected.weeklyPremium,
        amountPaidThisWeek=amount_paid_this_week,
        earningsProtected=round(settled_total, 2),
        parametricCoverageOn=status == "active",
        perTriggerPayout=selected.perTriggerPayout,
        maxDaysPerWeek=selected.maxDaysPerWeek,
        nextBillingDate=next_billing_date.isoformat(),
        cycleStartDate=cycle_start_date.isoformat(),
        cycleEndDate=cycle_end_date.isoformat(),
        paidOnDate=now.date().isoformat(),
        daysLeft=days_left,
    )


@router.get("/me", response_model=ApiResponse)
async def get_my_policy(worker: dict = Depends(get_current_worker)) -> ApiResponse:
    settled_total = await total_settled_amount_for_phone(str(worker["phone"]))
    payment_rows = await _authoritative_payment_rows(str(worker["phone"]))
    clean_streak_weeks = _clean_streak_weeks_from_paid_rows(payment_rows)
    loyalty_discount_percent = _loyalty_discount_percent(clean_streak_weeks)
    policy = _build_policy(worker, settled_total, payment_rows)
    policy.cleanStreakWeeks = clean_streak_weeks
    policy.loyaltyDiscountPercent = loyalty_discount_percent
    policy.weeklyPremium = _apply_loyalty_discount(policy.weeklyPremium, loyalty_discount_percent)
    policy.amountPaidThisWeek = float(policy.weeklyPremium) if policy.status == "active" else 0.0
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
        payment_rows = await _authoritative_payment_rows(str(worker["phone"]))
        clean_streak_weeks = _clean_streak_weeks_from_paid_rows(payment_rows)
        loyalty_discount_percent = _loyalty_discount_percent(clean_streak_weeks)
        policy = _build_policy(worker, settled_total, payment_rows)
        policy.cleanStreakWeeks = clean_streak_weeks
        policy.loyaltyDiscountPercent = loyalty_discount_percent
        policy.weeklyPremium = _apply_loyalty_discount(policy.weeklyPremium, loyalty_discount_percent)
        policy.amountPaidThisWeek = float(policy.weeklyPremium) if policy.status == "active" else 0.0
        return ApiResponse(success=True, data=policy, message="Selected plan is already active")

    next_week_effective_at = _next_week_start_utc(datetime.now(timezone.utc))
    await set_pending_worker_plan(str(worker["phone"]), selected.name, next_week_effective_at)
    worker["pending_plan_name"] = selected.name
    worker["pending_plan_effective_at"] = next_week_effective_at.isoformat()

    settled_total = await total_settled_amount_for_phone(str(worker["phone"]))
    payment_rows = await _authoritative_payment_rows(str(worker["phone"]))
    clean_streak_weeks = _clean_streak_weeks_from_paid_rows(payment_rows)
    loyalty_discount_percent = _loyalty_discount_percent(clean_streak_weeks)
    policy = _build_policy(worker, settled_total, payment_rows)
    policy.cleanStreakWeeks = clean_streak_weeks
    policy.loyaltyDiscountPercent = loyalty_discount_percent
    policy.weeklyPremium = _apply_loyalty_discount(policy.weeklyPremium, loyalty_discount_percent)
    policy.amountPaidThisWeek = float(policy.weeklyPremium) if policy.status == "active" else 0.0
    logger.info(
        "policy_change_queued phone=%s current_plan=%s pending_plan=%s effective_at=%s",
        worker["phone"],
        worker["plan_name"],
        selected.name,
        next_week_effective_at.isoformat(),
    )
    return ApiResponse(success=True, data=policy, message="Plan change queued for next week")


@router.post("/premium-payment", response_model=ApiResponse)
async def record_premium_payment(
    payload: PremiumPaymentRecordRequest,
    worker: dict = Depends(get_current_worker),
) -> ApiResponse:
    if settings.billing_service_enabled:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail="Client-reported premium payments have been retired.",
        )
    if not settings.allow_client_reported_premium_payments:
        raise HTTPException(
            status_code=403,
            detail="Premium payments must be server-verified before coverage is scheduled.",
        )
    payment_status = payload.status.strip().lower()
    if payment_status not in {"paid", "missed", "failed"}:
        raise HTTPException(status_code=400, detail="Invalid status. Use paid, missed, or failed")

    amount = float(payload.amount)
    if amount < 0:
        raise HTTPException(status_code=400, detail="Amount must be non-negative")

    week_start = _coerce_week_start(payload.weekStartDate)
    await upsert_premium_payment_week(
        phone=str(worker["phone"]),
        week_start_date=week_start,
        amount=amount,
        status=payment_status,
        provider_ref=payload.providerRef,
        metadata=payload.metadata,
    )

    # A successful payment always schedules coverage for the upcoming paid cycle,
    # never for the already-running week.
    if payment_status == "paid":
        effective_at = datetime(
            week_start.year,
            week_start.month,
            week_start.day,
            0,
            1,
            tzinfo=timezone.utc,
        )
        await set_pending_worker_plan(
            str(worker["phone"]),
            str(worker.get("plan_name") or ""),
            effective_at,
        )
        worker["pending_plan_name"] = str(worker.get("plan_name") or "")
        worker["pending_plan_effective_at"] = effective_at.isoformat()

    settled_total = await total_settled_amount_for_phone(str(worker["phone"]))
    payment_rows = await list_paid_premium_weeks_for_phone(str(worker["phone"]))
    clean_streak_weeks = _clean_streak_weeks_from_paid_rows(payment_rows)
    loyalty_discount_percent = _loyalty_discount_percent(clean_streak_weeks)
    policy = _build_policy(worker, settled_total, payment_rows)
    policy.cleanStreakWeeks = clean_streak_weeks
    policy.loyaltyDiscountPercent = loyalty_discount_percent
    policy.weeklyPremium = _apply_loyalty_discount(policy.weeklyPremium, loyalty_discount_percent)
    policy.amountPaidThisWeek = float(policy.weeklyPremium) if policy.status == "active" else 0.0

    logger.info(
        "premium_payment_recorded phone=%s status=%s week_start=%s amount=%s",
        worker["phone"],
        payment_status,
        week_start.isoformat(),
        amount,
    )
    return ApiResponse(success=True, data=policy, message="Premium payment recorded")


@router.post("/payment-orders", response_model=ApiResponse, status_code=status.HTTP_201_CREATED)
async def create_payment_order(
    payload: PaymentOrderCreateRequest,
    request: Request,
    worker: dict = Depends(get_current_worker),
) -> ApiResponse:
    if not settings.billing_service_enabled:
        raise HTTPException(status_code=503, detail="Billing service is disabled")

    platform = Platform.from_input(str(worker["platform_name"]))
    _, zone_data = resolve_zone(str(worker["zone_pincode"]))
    plans = build_plans(
        float(zone_data.get("zone_risk_multiplier", 1.0)), platform, zone_data=zone_data
    )
    week_start = _next_week_start_utc(datetime.now(timezone.utc)).date()
    plan_name = _plan_name_for_coverage_week(worker, week_start)
    selected = next((plan for plan in plans if plan.name.lower() == plan_name.lower()), None)
    if selected is None:
        raise HTTPException(status_code=400, detail="Worker has an unknown plan")

    # Spring is the payment system of record. Until its ledger exposes a loyalty
    # summary, never apply discounts from the retired FastAPI payment table.
    payment_rows: list[dict] = []
    discount = _loyalty_discount_percent(_clean_streak_weeks_from_paid_rows(payment_rows))
    premium = _apply_loyalty_discount(selected.weeklyPremium, discount)
    command = PaymentOrderCreate(
        worker_phone=str(worker["phone"]),
        plan_code=selected.name.strip().lower(),
        amount=Decimal(premium).quantize(Decimal("0.01")),
        currency="INR",
        coverage_week_start=week_start,
        idempotency_key=payload.clientRequestId,
        correlation_id=request.headers.get("X-Correlation-Id"),
    )
    try:
        order = await get_billing_client().create_payment_order(command)
    except BillingServiceError as exc:
        raise _billing_http_error(exc) from exc
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="Billing service returned an invalid response") from exc
    return ApiResponse(success=True, data=_payment_order_out(order))


@router.get("/payment-orders/{order_id}", response_model=ApiResponse)
async def get_payment_order(
    order_id: str,
    worker: dict = Depends(get_current_worker),
) -> ApiResponse:
    if not settings.billing_service_enabled:
        raise HTTPException(status_code=503, detail="Billing service is disabled")
    try:
        order = await get_billing_client().get_payment_order(order_id, str(worker["phone"]))
    except BillingServiceError as exc:
        raise _billing_http_error(exc) from exc
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="Billing service returned an invalid response") from exc
    return ApiResponse(success=True, data=_payment_order_out(order))


@router.post("/payment-orders/{order_id}/sandbox-complete", response_model=ApiResponse)
async def complete_sandbox_payment_order(
    order_id: str,
    worker: dict = Depends(get_current_worker),
) -> ApiResponse:
    environment = settings.app_environment.strip().lower()
    if environment in {"production", "prod"}:
        raise HTTPException(status_code=403, detail="Sandbox completion is unavailable in production")
    if not settings.billing_service_enabled:
        raise HTTPException(status_code=503, detail="Billing service is disabled")
    client = get_billing_client()
    try:
        current = await client.get_payment_order(order_id, str(worker["phone"]))
        if current.provider != "sandbox":
            raise HTTPException(status_code=409, detail="Payment order does not use the sandbox provider")
        order = await client.complete_sandbox_order(order_id, str(worker["phone"]))
    except BillingServiceError as exc:
        raise _billing_http_error(exc) from exc
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="Billing service returned an invalid response") from exc
    return ApiResponse(success=True, data=_payment_order_out(order))
