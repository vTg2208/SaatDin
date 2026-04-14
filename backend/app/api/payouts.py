from __future__ import annotations

from datetime import datetime, time, timezone

from fastapi import APIRouter, Depends, HTTPException, Query

from ..core.dependencies import get_current_worker
from ..models.schemas import ApiResponse, PayoutAccountUpdateRequest
from ..services.payouts import build_statement, get_worker_payout_dashboard, update_upi_account, verify_upi_account

router = APIRouter(tags=["payouts"])


@router.get("/me", response_model=ApiResponse)
async def get_my_payouts(worker: dict = Depends(get_current_worker)) -> ApiResponse:
    dashboard = await get_worker_payout_dashboard(str(worker["phone"]))
    return ApiResponse(success=True, data=dashboard)


@router.put("/accounts/{slot}", response_model=ApiResponse)
async def update_payout_account(
    slot: str,
    payload: PayoutAccountUpdateRequest,
    worker: dict = Depends(get_current_worker),
) -> ApiResponse:
    try:
        dashboard = await update_upi_account(str(worker["phone"]), slot=slot, upi_id=payload.upiId)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return ApiResponse(success=True, data=dashboard, message="Payout account updated")


@router.post("/accounts/{slot}/verify", response_model=ApiResponse)
async def verify_payout_account(slot: str, worker: dict = Depends(get_current_worker)) -> ApiResponse:
    try:
        dashboard = await verify_upi_account(str(worker["phone"]), slot=slot)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return ApiResponse(success=True, data=dashboard, message="UPI account verified")


@router.get("/statements", response_model=ApiResponse)
async def get_statement(
    startDate: str = Query(..., min_length=10, max_length=10),
    endDate: str = Query(..., min_length=10, max_length=10),
    worker: dict = Depends(get_current_worker),
) -> ApiResponse:
    try:
        start = datetime.combine(datetime.fromisoformat(startDate).date(), time.min, tzinfo=timezone.utc)
        end = datetime.combine(datetime.fromisoformat(endDate).date(), time.max, tzinfo=timezone.utc)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD.") from exc
    statement = await build_statement(str(worker["phone"]), start=start, end=end)
    return ApiResponse(success=True, data=statement)
