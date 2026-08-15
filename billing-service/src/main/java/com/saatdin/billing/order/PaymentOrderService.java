package com.saatdin.billing.order;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.saatdin.billing.provider.PaymentProvider;
import com.saatdin.billing.provider.ProviderOrder;
import com.saatdin.billing.payment.BillingMetrics;

@Service
public class PaymentOrderService {

	private static final Duration ORDER_LIFETIME = Duration.ofMinutes(15);

	private final PaymentOrderRepository repository;
	private final PaymentProvider provider;
	private final BillingMetrics metrics;
	private final Clock clock;

	public PaymentOrderService(
			PaymentOrderRepository repository, PaymentProvider provider, BillingMetrics metrics, Clock clock) {
		this.repository = repository;
		this.provider = provider;
		this.metrics = metrics;
		this.clock = clock;
	}

	@Transactional
	public PaymentOrder create(CreatePaymentOrderCommand command, String idempotencyKey) {
		Objects.requireNonNull(command, "payment order command is required");
		String key = normalizeKey(idempotencyKey);
		repository.acquireIdempotencyLock(key);

		return repository.findByIdempotencyKey(key)
				.map(existing -> requireSameRequest(existing, command))
				.orElseGet(() -> createNew(command, key));
	}

	private PaymentOrder createNew(CreatePaymentOrderCommand command, String key) {
		Instant now = clock.instant();
		PaymentOrder order = PaymentOrder.create(
				UUID.randomUUID(),
				command.workerPhone(),
				command.planCode(),
				command.amount(),
				command.currency(),
				command.coverageWeekStart(),
				provider.name(),
				key,
				now.plus(ORDER_LIFETIME),
				now);
		ProviderOrder providerOrder = provider.createOrder(order.id(), order.amount(), order.currency());
		order.markPending(clock.instant(), providerOrder.providerOrderId());
		PaymentOrder saved = repository.save(order);
		metrics.orderCreated();
		return saved;
	}

	private PaymentOrder requireSameRequest(PaymentOrder existing, CreatePaymentOrderCommand command) {
		boolean same = existing.workerPhone().equals(command.workerPhone())
				&& existing.planCode().equals(command.planCode())
				&& existing.amount().compareTo(command.amount()) == 0
				&& existing.currency().equals(command.currency())
				&& existing.coverageWeekStart().equals(command.coverageWeekStart())
				&& existing.provider().equals(provider.name());
		if (!same) {
			throw new IdempotencyConflictException();
		}
		return existing;
	}

	private static String normalizeKey(String value) {
		if (value == null || value.isBlank()) {
			throw new IllegalArgumentException("idempotency key is required");
		}
		String normalized = value.trim();
		if (normalized.length() > 120) {
			throw new IllegalArgumentException("idempotency key must not exceed 120 characters");
		}
		return normalized;
	}
}
