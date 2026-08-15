package com.saatdin.billing.provider;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

import com.saatdin.billing.order.PaymentOrderStatus;

public record VerifiedPaymentEvent(
		String providerEventId,
		String providerPaymentId,
		UUID orderId,
		PaymentOrderStatus status,
		BigDecimal amount,
		String currency,
		Instant occurredAt) {

	public VerifiedPaymentEvent {
		providerEventId = requireText(providerEventId, "provider event id");
		providerPaymentId = requireText(providerPaymentId, "provider payment id");
		Objects.requireNonNull(orderId, "order id is required");
		Objects.requireNonNull(status, "status is required");
		if (status != PaymentOrderStatus.PAID
				&& status != PaymentOrderStatus.FAILED
				&& status != PaymentOrderStatus.REFUNDED) {
			throw new IllegalArgumentException("unsupported payment status: " + status);
		}
		if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
			throw new IllegalArgumentException("amount must be positive");
		}
		currency = requireText(currency, "currency").toUpperCase();
		if (!"INR".equals(currency)) {
			throw new IllegalArgumentException("currency must be INR");
		}
		Objects.requireNonNull(occurredAt, "occurrence time is required");
	}

	private static String requireText(String value, String field) {
		if (value == null || value.isBlank()) {
			throw new IllegalArgumentException(field + " is required");
		}
		return value.trim();
	}
}
