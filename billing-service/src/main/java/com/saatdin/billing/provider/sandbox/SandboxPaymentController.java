package com.saatdin.billing.provider.sandbox;

import java.time.Clock;
import java.util.UUID;

import org.springframework.context.annotation.Profile;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.saatdin.billing.order.PaymentOrder;
import com.saatdin.billing.order.PaymentOrderNotFoundException;
import com.saatdin.billing.order.PaymentOrderRepository;
import com.saatdin.billing.order.PaymentOrderView;
import com.saatdin.billing.payment.WebhookProcessingService;
import com.saatdin.billing.provider.sandbox.SandboxPaymentProvider.SandboxWebhook;

@Profile("sandbox")
@RestController
@RequestMapping("/sandbox/v1/payment-orders")
public class SandboxPaymentController {

	private final PaymentOrderRepository repository;
	private final SandboxPaymentProvider provider;
	private final WebhookProcessingService webhookService;
	private final Clock clock;

	public SandboxPaymentController(
			PaymentOrderRepository repository,
			SandboxPaymentProvider provider,
			WebhookProcessingService webhookService,
			Clock clock) {
		this.repository = repository;
		this.provider = provider;
		this.webhookService = webhookService;
		this.clock = clock;
	}

	@PostMapping("/{orderId}/complete")
	public PaymentOrderView complete(@PathVariable UUID orderId) {
		PaymentOrder order = repository.findById(orderId)
				.orElseThrow(() -> new PaymentOrderNotFoundException(orderId));
		SandboxWebhook webhook = provider.createPaidWebhook(order, clock.instant());
		webhookService.process(provider.name(), webhook.signature(), webhook.body());
		PaymentOrder updated = repository.findById(orderId)
				.orElseThrow(() -> new PaymentOrderNotFoundException(orderId));
		return PaymentOrderView.from(updated);
	}
}
