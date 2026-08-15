package com.saatdin.billing.order;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PaymentOrderQueryService {

	private final PaymentOrderRepository repository;
	private final Clock clock;

	public PaymentOrderQueryService(PaymentOrderRepository repository, Clock clock) {
		this.repository = repository;
		this.clock = clock;
	}

	@Transactional
	public PaymentOrder getOwned(UUID orderId, String workerPhone) {
		String normalizedPhone = WorkerPhone.normalize(workerPhone);
		PaymentOrder order = repository.findByIdAndWorkerPhone(orderId, normalizedPhone)
				.orElseThrow(() -> new PaymentOrderNotFoundException(orderId));
		Instant now = clock.instant();
		if (order.status() == PaymentOrderStatus.PENDING && !order.expiresAt().isAfter(now)) {
			order.markExpired(now);
			repository.save(order);
		}
		return order;
	}
}
