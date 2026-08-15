package com.saatdin.billing.order;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import org.junit.jupiter.api.Test;

class PaymentOrderTest {

	private static final Instant CREATED_AT = Instant.parse("2026-08-15T06:30:00Z");
	private static final Instant UPDATED_AT = Instant.parse("2026-08-15T06:31:00Z");

	@Test
	void pendingOrderCanBecomePaid() {
		PaymentOrder order = newOrder();

		order.markPending(UPDATED_AT, "sandbox-order-1");
		order.markPaid(UPDATED_AT.plusSeconds(60));

		assertThat(order.status()).isEqualTo(PaymentOrderStatus.PAID);
	}

	@Test
	void failedOrderCannotBecomePaid() {
		PaymentOrder order = newOrder();
		order.markFailed(UPDATED_AT);

		assertThatThrownBy(() -> order.markPaid(UPDATED_AT.plusSeconds(60)))
				.isInstanceOf(InvalidPaymentTransitionException.class);
	}

	@Test
	void repeatingCurrentStateIsIdempotent() {
		PaymentOrder order = newOrder();
		order.markPending(UPDATED_AT, "sandbox-order-1");

		order.markPending(UPDATED_AT.plusSeconds(60), "sandbox-order-1");

		assertThat(order.status()).isEqualTo(PaymentOrderStatus.PENDING);
		assertThat(order.providerOrderId()).isEqualTo("sandbox-order-1");
	}

	@Test
	void pendingOrderCanExpire() {
		PaymentOrder order = newOrder();
		order.markPending(UPDATED_AT, "sandbox-order-1");

		order.markExpired(UPDATED_AT.plusSeconds(60));

		assertThat(order.status()).isEqualTo(PaymentOrderStatus.EXPIRED);
	}

	@Test
	void paidOrderCanBeRefunded() {
		PaymentOrder order = newOrder();
		order.markPending(UPDATED_AT, "sandbox-order-1");
		order.markPaid(UPDATED_AT.plusSeconds(60));

		order.markRefunded(UPDATED_AT.plusSeconds(120));

		assertThat(order.status()).isEqualTo(PaymentOrderStatus.REFUNDED);
	}

	@Test
	void createdOrderCannotBecomePaidWithoutProviderAcceptance() {
		PaymentOrder order = newOrder();

		assertThatThrownBy(() -> order.markPaid(UPDATED_AT))
				.isInstanceOf(InvalidPaymentTransitionException.class);
	}

	@Test
	void orderRejectsNonPositiveAmount() {
		assertThatThrownBy(() -> create(new BigDecimal("0.00"), LocalDate.of(2026, 8, 17)))
				.isInstanceOf(IllegalArgumentException.class)
				.hasMessageContaining("amount");
	}

	@Test
	void orderRejectsCoverageWeekThatDoesNotStartOnMonday() {
		assertThatThrownBy(() -> create(new BigDecimal("75.00"), LocalDate.of(2026, 8, 16)))
				.isInstanceOf(IllegalArgumentException.class)
				.hasMessageContaining("Monday");
	}

	@Test
	void orderRejectsUnsupportedCurrency() {
		assertThatThrownBy(() -> PaymentOrder.create(
				UUID.fromString("63c40536-b23a-4d52-8360-1a08454dcd10"),
				"9876543210",
				"standard",
				new BigDecimal("75.00"),
				"USD",
				LocalDate.of(2026, 8, 17),
				"sandbox",
				"checkout-123",
				CREATED_AT.plusSeconds(900),
				CREATED_AT))
				.isInstanceOf(IllegalArgumentException.class)
				.hasMessageContaining("INR");
	}

	private static PaymentOrder newOrder() {
		return create(new BigDecimal("75.00"), LocalDate.of(2026, 8, 17));
	}

	private static PaymentOrder create(BigDecimal amount, LocalDate weekStart) {
		return PaymentOrder.create(
				UUID.fromString("63c40536-b23a-4d52-8360-1a08454dcd10"),
				"9876543210",
				"standard",
				amount,
				"INR",
				weekStart,
				"sandbox",
				"checkout-123",
				CREATED_AT.plusSeconds(900),
				CREATED_AT);
	}
}
