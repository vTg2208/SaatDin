package com.saatdin.billing.payment;

import java.util.function.Supplier;

import org.springframework.stereotype.Component;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;

@Component
public class BillingMetrics {

	private final MeterRegistry registry;

	public BillingMetrics(MeterRegistry registry) {
		this.registry = registry;
	}

	public void orderCreated() { registry.counter("billing.orders.created").increment(); }
	public void paymentPaid() { registry.counter("billing.payments.paid").increment(); }
	public void paymentFailed() { registry.counter("billing.payments.failed").increment(); }
	public void duplicateWebhook() { registry.counter("billing.webhooks.duplicate").increment(); }
	public void signatureFailed() { registry.counter("billing.webhooks.signature-failed").increment(); }

	public <T> T timeCoverageQuery(Supplier<T> query) {
		return Timer.builder("billing.coverage.query").register(registry).record(query);
	}
}
