package com.saatdin.billing.order;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

public record PaymentOrderView(
		UUID orderId,
		PaymentOrderStatus status,
		String provider,
		BigDecimal amount,
		String currency,
		LocalDate coverageWeekStart,
		Instant expiresAt,
		Map<String, Object> checkoutData) {

	public static PaymentOrderView from(PaymentOrder order) {
		Map<String, Object> checkout = order.providerOrderId() == null
				? Map.of()
				: Map.of("providerOrderId", order.providerOrderId());
		return new PaymentOrderView(
				order.id(), order.status(), order.provider(), order.amount(), order.currency(),
				order.coverageWeekStart(), order.expiresAt(), checkout);
	}
}
