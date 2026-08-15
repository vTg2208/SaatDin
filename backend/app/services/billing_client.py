from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Any
from uuid import UUID, uuid4

import httpx


ORDER_STATUSES = frozenset({"CREATED", "PENDING", "PAID", "FAILED", "EXPIRED", "REFUNDED"})


@dataclass(frozen=True)
class PaymentOrderCreate:
    worker_phone: str
    plan_code: str
    amount: Decimal
    currency: str
    coverage_week_start: date
    idempotency_key: str
    correlation_id: str | None = None


@dataclass(frozen=True)
class PaymentOrderView:
    order_id: UUID
    status: str
    provider: str
    amount: Decimal
    currency: str
    coverage_week_start: date
    expires_at: datetime
    checkout_data: dict[str, Any]

    @property
    def is_paid(self) -> bool:
        return self.status == "PAID"

    @property
    def is_pending(self) -> bool:
        return self.status in {"CREATED", "PENDING"}


class BillingServiceError(RuntimeError):
    def __init__(self, message: str, status_code: int | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code


class BillingClient:
    def __init__(
        self,
        base_url: str,
        api_key: str,
        *,
        timeout_seconds: float = 2.0,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        timeout = httpx.Timeout(timeout_seconds, connect=min(timeout_seconds, 1.0))
        self._client = httpx.AsyncClient(
            base_url=base_url.rstrip("/"),
            timeout=timeout,
            transport=transport,
            headers={"X-Internal-Api-Key": api_key, "Accept": "application/json"},
        )

    async def close(self) -> None:
        await self._client.aclose()

    async def create_payment_order(self, request: PaymentOrderCreate) -> PaymentOrderView:
        response = await self._client.post(
            "/internal/v1/payment-orders",
            headers={
                "Idempotency-Key": request.idempotency_key,
                "X-Correlation-Id": request.correlation_id or str(uuid4()),
            },
            json={
                "workerPhone": request.worker_phone,
                "planCode": request.plan_code,
                "amount": format(request.amount, ".2f"),
                "currency": request.currency,
                "coverageWeekStart": request.coverage_week_start.isoformat(),
            },
        )
        return _parse_order_response(response)

    async def get_payment_order(self, order_id: str, worker_phone: str) -> PaymentOrderView:
        response = await self._client.get(
            f"/internal/v1/payment-orders/{UUID(order_id)}",
            params={"workerPhone": worker_phone},
        )
        return _parse_order_response(response)

    async def complete_sandbox_order(self, order_id: str, worker_phone: str) -> PaymentOrderView:
        response = await self._client.post(
            f"/sandbox/v1/payment-orders/{UUID(order_id)}/complete",
            params={"workerPhone": worker_phone},
        )
        return _parse_order_response(response)

    async def has_active_coverage(self, phone: str, at: date) -> bool:
        try:
            response = await self._client.get(
                f"/internal/v1/coverage/{phone}", params={"at": at.isoformat()}
            )
            response.raise_for_status()
            payload = response.json()
            if not isinstance(payload, dict) or type(payload.get("active")) is not bool:
                return False
            if payload["active"]:
                _parse_date(payload.get("startsOn"), "startsOn")
                _parse_date(payload.get("endsOn"), "endsOn")
                if not isinstance(payload.get("planCode"), str) or not payload["planCode"].strip():
                    return False
            return payload["active"]
        except (httpx.HTTPError, TypeError, ValueError):
            return False


def _parse_order_response(response: httpx.Response) -> PaymentOrderView:
    try:
        response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        raise BillingServiceError(
            f"billing service returned HTTP {response.status_code}", response.status_code
        ) from exc
    payload = response.json()
    if not isinstance(payload, dict):
        raise ValueError("billing order response must be an object")

    status = payload.get("status")
    if status not in ORDER_STATUSES:
        raise ValueError("billing order response has an invalid status")
    provider = payload.get("provider")
    if not isinstance(provider, str) or not provider.strip() or len(provider) > 40:
        raise ValueError("billing order response has an invalid provider")
    currency = payload.get("currency")
    if currency != "INR":
        raise ValueError("billing order response has an invalid currency")
    try:
        amount = Decimal(str(payload.get("amount")))
    except (InvalidOperation, TypeError) as exc:
        raise ValueError("billing order response has an invalid amount") from exc
    if not amount.is_finite() or amount <= 0 or amount.as_tuple().exponent < -2:
        raise ValueError("billing order response has an invalid amount")
    checkout = payload.get("checkoutData")
    if not isinstance(checkout, dict):
        raise ValueError("billing order response has invalid checkout data")

    return PaymentOrderView(
        order_id=UUID(str(payload.get("orderId"))),
        status=status,
        provider=provider,
        amount=amount,
        currency=currency,
        coverage_week_start=_parse_date(payload.get("coverageWeekStart"), "coverageWeekStart"),
        expires_at=_parse_datetime(payload.get("expiresAt")),
        checkout_data=dict(checkout),
    )


def _parse_date(value: Any, field: str) -> date:
    if not isinstance(value, str):
        raise ValueError(f"billing response has an invalid {field}")
    return date.fromisoformat(value)


def _parse_datetime(value: Any) -> datetime:
    if not isinstance(value, str):
        raise ValueError("billing order response has an invalid expiration")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("billing order expiration must include a timezone")
    return parsed.astimezone(timezone.utc)


_billing_client: BillingClient | None = None


async def initialize_billing_client(runtime_settings: Any) -> None:
    global _billing_client
    if not bool(getattr(runtime_settings, "billing_service_enabled", False)):
        _billing_client = None
        return
    _billing_client = BillingClient(
        str(runtime_settings.billing_service_url),
        str(runtime_settings.billing_service_api_key),
        timeout_seconds=float(runtime_settings.billing_request_timeout_seconds),
    )


async def close_billing_client() -> None:
    global _billing_client
    if _billing_client is not None:
        await _billing_client.close()
        _billing_client = None


def get_billing_client() -> BillingClient:
    if _billing_client is None:
        raise BillingServiceError("billing client is not initialized")
    return _billing_client
