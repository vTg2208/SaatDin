from __future__ import annotations

from datetime import date
from decimal import Decimal
import json
import unittest
from uuid import UUID

import httpx

from backend.app.services.billing_client import BillingClient, PaymentOrderCreate


class BillingClientTests(unittest.IsolatedAsyncioTestCase):
    async def test_create_order_sends_internal_idempotency_and_correlation_headers(self) -> None:
        captured: dict[str, object] = {}

        def handler(request: httpx.Request) -> httpx.Response:
            captured["headers"] = request.headers
            captured["json"] = json.loads(request.content)
            return httpx.Response(201, json=_order_response())

        client = BillingClient(
            "http://billing.internal:8082",
            "k" * 32,
            timeout_seconds=1.5,
            transport=httpx.MockTransport(handler),
        )
        try:
            order = await client.create_payment_order(
                PaymentOrderCreate(
                    worker_phone="9876543210",
                    plan_code="standard",
                    amount=Decimal("75.00"),
                    currency="INR",
                    coverage_week_start=date(2026, 8, 17),
                    idempotency_key="checkout-123",
                    correlation_id="corr-456",
                )
            )
        finally:
            await client.close()

        headers = captured["headers"]
        assert isinstance(headers, httpx.Headers)
        self.assertEqual(headers["X-Internal-Api-Key"], "k" * 32)
        self.assertEqual(headers["Idempotency-Key"], "checkout-123")
        self.assertEqual(headers["X-Correlation-Id"], "corr-456")
        self.assertEqual(captured["json"]["amount"], "75.00")  # type: ignore[index]
        self.assertEqual(order.order_id, UUID("63c40536-b23a-4d52-8360-1a08454dcd10"))
        self.assertEqual(order.amount, Decimal("75.00"))

    async def test_coverage_is_false_on_server_error(self) -> None:
        client = BillingClient(
            "http://billing.internal:8082",
            "k" * 32,
            transport=httpx.MockTransport(lambda _: httpx.Response(503)),
        )
        try:
            self.assertFalse(await client.has_active_coverage("9876543210", date(2026, 8, 17)))
        finally:
            await client.close()

    async def test_coverage_is_false_on_malformed_response(self) -> None:
        client = BillingClient(
            "http://billing.internal:8082",
            "k" * 32,
            transport=httpx.MockTransport(lambda _: httpx.Response(200, json={"active": "yes"})),
        )
        try:
            self.assertFalse(await client.has_active_coverage("9876543210", date(2026, 8, 17)))
        finally:
            await client.close()

    async def test_order_response_rejects_unknown_status(self) -> None:
        payload = _order_response()
        payload["status"] = "SETTLED"
        client = BillingClient(
            "http://billing.internal:8082",
            "k" * 32,
            transport=httpx.MockTransport(lambda _: httpx.Response(200, json=payload)),
        )
        try:
            with self.assertRaises(ValueError):
                await client.get_payment_order(
                    "63c40536-b23a-4d52-8360-1a08454dcd10", "9876543210"
                )
        finally:
            await client.close()


def _order_response() -> dict[str, object]:
    return {
        "orderId": "63c40536-b23a-4d52-8360-1a08454dcd10",
        "status": "PENDING",
        "provider": "sandbox",
        "amount": 75.00,
        "currency": "INR",
        "coverageWeekStart": "2026-08-17",
        "expiresAt": "2026-08-15T08:15:00Z",
        "checkoutData": {"providerOrderId": "sandbox-order-1"},
    }


if __name__ == "__main__":
    unittest.main()
