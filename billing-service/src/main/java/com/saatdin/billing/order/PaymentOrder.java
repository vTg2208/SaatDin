package com.saatdin.billing.order;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

@Entity
@Table(name = "payment_orders", schema = "billing")
public class PaymentOrder {

	@Id
	private UUID id;

	@Column(name = "worker_phone", nullable = false, length = 15)
	private String workerPhone;

	@Column(name = "plan_code", nullable = false, length = 40)
	private String planCode;

	@Column(nullable = false, precision = 12, scale = 2)
	private BigDecimal amount;

	@Column(nullable = false, length = 3)
	private String currency;

	@Column(name = "coverage_week_start", nullable = false)
	private LocalDate coverageWeekStart;

	@Column(nullable = false, length = 40)
	private String provider;

	@Column(name = "idempotency_key", nullable = false, length = 120, unique = true)
	private String idempotencyKey;

	@Column(name = "expires_at", nullable = false)
	private Instant expiresAt;

	@Column(name = "created_at", nullable = false, updatable = false)
	private Instant createdAt;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 24)
	private PaymentOrderStatus status;

	@Column(name = "provider_order_id", length = 160)
	private String providerOrderId;

	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;

	protected PaymentOrder() {
	}

	private PaymentOrder(
			UUID id,
			String workerPhone,
			String planCode,
			BigDecimal amount,
			String currency,
			LocalDate coverageWeekStart,
			String provider,
			String idempotencyKey,
			Instant expiresAt,
			Instant createdAt) {
		this.id = Objects.requireNonNull(id, "id is required");
		this.workerPhone = requireText(workerPhone, "worker phone");
		this.planCode = requireText(planCode, "plan code");
		this.amount = requirePositiveAmount(amount);
		this.currency = requireInr(currency);
		this.coverageWeekStart = requireMonday(coverageWeekStart);
		this.provider = requireText(provider, "provider");
		this.idempotencyKey = requireText(idempotencyKey, "idempotency key");
		this.expiresAt = Objects.requireNonNull(expiresAt, "expiration is required");
		this.createdAt = Objects.requireNonNull(createdAt, "creation time is required");
		if (!expiresAt.isAfter(createdAt)) {
			throw new IllegalArgumentException("expiration must be after creation time");
		}
		this.status = PaymentOrderStatus.CREATED;
		this.updatedAt = createdAt;
	}

	public static PaymentOrder create(
			UUID id,
			String workerPhone,
			String planCode,
			BigDecimal amount,
			String currency,
			LocalDate coverageWeekStart,
			String provider,
			String idempotencyKey,
			Instant expiresAt,
			Instant createdAt) {
		return new PaymentOrder(
				id,
				workerPhone,
				planCode,
				amount,
				currency,
				coverageWeekStart,
				provider,
				idempotencyKey,
				expiresAt,
				createdAt);
	}

	public void markPending(Instant changedAt, String acceptedProviderOrderId) {
		String normalizedProviderOrderId = requireText(acceptedProviderOrderId, "provider order id");
		if (status == PaymentOrderStatus.PENDING) {
			if (!normalizedProviderOrderId.equals(providerOrderId)) {
				throw new InvalidPaymentTransitionException(status, PaymentOrderStatus.PENDING);
			}
			return;
		}
		requireTransition(PaymentOrderStatus.CREATED, PaymentOrderStatus.PENDING);
		providerOrderId = normalizedProviderOrderId;
		update(PaymentOrderStatus.PENDING, changedAt);
	}

	public void markPaid(Instant changedAt) {
		transition(PaymentOrderStatus.PENDING, PaymentOrderStatus.PAID, changedAt);
	}

	public void markFailed(Instant changedAt) {
		if (status == PaymentOrderStatus.FAILED) {
			return;
		}
		if (status != PaymentOrderStatus.CREATED && status != PaymentOrderStatus.PENDING) {
			throw new InvalidPaymentTransitionException(status, PaymentOrderStatus.FAILED);
		}
		update(PaymentOrderStatus.FAILED, changedAt);
	}

	public void markExpired(Instant changedAt) {
		transition(PaymentOrderStatus.PENDING, PaymentOrderStatus.EXPIRED, changedAt);
	}

	public void markRefunded(Instant changedAt) {
		transition(PaymentOrderStatus.PAID, PaymentOrderStatus.REFUNDED, changedAt);
	}

	private void transition(PaymentOrderStatus expected, PaymentOrderStatus target, Instant changedAt) {
		if (status == target) {
			return;
		}
		requireTransition(expected, target);
		update(target, changedAt);
	}

	private void requireTransition(PaymentOrderStatus expected, PaymentOrderStatus target) {
		if (status != expected) {
			throw new InvalidPaymentTransitionException(status, target);
		}
	}

	private void update(PaymentOrderStatus target, Instant changedAt) {
		Instant nextUpdatedAt = Objects.requireNonNull(changedAt, "transition time is required");
		if (nextUpdatedAt.isBefore(updatedAt)) {
			throw new IllegalArgumentException("transition time cannot move backwards");
		}
		status = target;
		updatedAt = nextUpdatedAt;
	}

	private static String requireText(String value, String field) {
		if (value == null || value.isBlank()) {
			throw new IllegalArgumentException(field + " is required");
		}
		return value.trim();
	}

	private static BigDecimal requirePositiveAmount(BigDecimal value) {
		if (value == null || value.compareTo(BigDecimal.ZERO) <= 0) {
			throw new IllegalArgumentException("amount must be positive");
		}
		return value;
	}

	private static String requireInr(String value) {
		String normalized = requireText(value, "currency").toUpperCase();
		if (!"INR".equals(normalized)) {
			throw new IllegalArgumentException("currency must be INR");
		}
		return normalized;
	}

	private static LocalDate requireMonday(LocalDate value) {
		if (value == null || value.getDayOfWeek() != DayOfWeek.MONDAY) {
			throw new IllegalArgumentException("coverage week must start on Monday");
		}
		return value;
	}

	public UUID id() {
		return id;
	}

	public String workerPhone() {
		return workerPhone;
	}

	public String planCode() {
		return planCode;
	}

	public BigDecimal amount() {
		return amount;
	}

	public String currency() {
		return currency;
	}

	public LocalDate coverageWeekStart() {
		return coverageWeekStart;
	}

	public String provider() {
		return provider;
	}

	public String idempotencyKey() {
		return idempotencyKey;
	}

	public Instant expiresAt() {
		return expiresAt;
	}

	public Instant createdAt() {
		return createdAt;
	}

	public PaymentOrderStatus status() {
		return status;
	}

	public String providerOrderId() {
		return providerOrderId;
	}

	public Instant updatedAt() {
		return updatedAt;
	}
}
