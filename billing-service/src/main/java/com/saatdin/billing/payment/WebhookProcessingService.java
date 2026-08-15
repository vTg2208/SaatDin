package com.saatdin.billing.payment;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.saatdin.billing.coverage.CoveragePeriod;
import com.saatdin.billing.coverage.CoveragePeriodRepository;
import com.saatdin.billing.order.PaymentOrder;
import com.saatdin.billing.order.PaymentOrderNotFoundException;
import com.saatdin.billing.order.PaymentOrderRepository;
import com.saatdin.billing.outbox.OutboxEvent;
import com.saatdin.billing.outbox.OutboxEventRepository;
import com.saatdin.billing.provider.InvalidWebhookSignatureException;
import com.saatdin.billing.provider.PaymentProvider;
import com.saatdin.billing.provider.VerifiedPaymentEvent;

@Service
public class WebhookProcessingService {

	private final Map<String, PaymentProvider> providers;
	private final PaymentOrderRepository orderRepository;
	private final PaymentTransactionRepository transactionRepository;
	private final WebhookReceiptRepository receiptRepository;
	private final CoveragePeriodRepository coverageRepository;
	private final OutboxEventRepository outboxRepository;
	private final BillingMetrics metrics;
	private final Clock clock;

	public WebhookProcessingService(
			List<PaymentProvider> providers,
			PaymentOrderRepository orderRepository,
			PaymentTransactionRepository transactionRepository,
			WebhookReceiptRepository receiptRepository,
			CoveragePeriodRepository coverageRepository,
			OutboxEventRepository outboxRepository,
			BillingMetrics metrics,
			Clock clock) {
		this.providers = providers.stream().collect(Collectors.toUnmodifiableMap(PaymentProvider::name, Function.identity()));
		this.orderRepository = orderRepository;
		this.transactionRepository = transactionRepository;
		this.receiptRepository = receiptRepository;
		this.coverageRepository = coverageRepository;
		this.outboxRepository = outboxRepository;
		this.metrics = metrics;
		this.clock = clock;
	}

	@Transactional
	public WebhookResult process(String providerName, String signature, byte[] body) {
		PaymentProvider provider = providers.get(providerName);
		if (provider == null) {
			throw new IllegalArgumentException("unsupported payment provider");
		}

		VerifiedPaymentEvent event;
		try {
			event = provider.verifyWebhook(signature, body);
		}
		catch (InvalidWebhookSignatureException exception) {
			metrics.signatureFailed();
			throw exception;
		}

		receiptRepository.acquireEventLock(providerName + ":" + event.providerEventId());
		if (receiptRepository.findByProviderAndProviderEventId(providerName, event.providerEventId()).isPresent()) {
			metrics.duplicateWebhook();
			return WebhookResult.DUPLICATE;
		}

		PaymentOrder order = orderRepository.findByIdForUpdate(event.orderId())
				.orElseThrow(() -> new PaymentOrderNotFoundException(event.orderId()));
		validateEvent(providerName, order, event);
		Instant now = clock.instant();
		WebhookReceipt receipt = WebhookReceipt.received(providerName, event.providerEventId(), sha256(body), now);

		switch (event.status()) {
			case PAID -> capturePayment(providerName, order, event, now);
			case FAILED -> failPayment(order, now);
			case REFUNDED -> refundPayment(providerName, order, event, now);
			default -> throw new IllegalArgumentException("unsupported verified payment event status");
		}
		receipt.markProcessed(now);
		receiptRepository.save(receipt);
		return WebhookResult.PROCESSED;
	}

	private void capturePayment(String provider, PaymentOrder order, VerifiedPaymentEvent event, Instant now) {
		order.markPaid(now);
		orderRepository.save(order);
		transactionRepository.save(PaymentTransaction.captured(order, event, provider, now));
		CoveragePeriod coverage = CoveragePeriod.activate(order, now);
		coverageRepository.save(coverage);
		outboxRepository.save(OutboxEvent.coverage(
				order.id(), "coverage.activated", coveragePayload(order, "ACTIVE"), now));
		metrics.paymentPaid();
	}

	private void failPayment(PaymentOrder order, Instant now) {
		order.markFailed(now);
		orderRepository.save(order);
		metrics.paymentFailed();
	}

	private void refundPayment(
			String provider, PaymentOrder order, VerifiedPaymentEvent event, Instant now) {
		order.markRefunded(now);
		orderRepository.save(order);
		PaymentTransaction transaction = transactionRepository
				.findByProviderAndProviderPaymentId(provider, event.providerPaymentId())
				.orElseThrow(() -> new PaymentEventMismatchException("captured transaction not found"));
		transaction.markRefunded();
		transactionRepository.save(transaction);
		CoveragePeriod coverage = coverageRepository.findByPaymentOrderId(order.id())
				.orElseThrow(() -> new PaymentEventMismatchException("coverage period not found"));
		coverage.revoke(now);
		coverageRepository.save(coverage);
		outboxRepository.save(OutboxEvent.coverage(
				order.id(), "coverage.revoked", coveragePayload(order, "REVOKED"), now));
	}

	private static void validateEvent(String provider, PaymentOrder order, VerifiedPaymentEvent event) {
		if (!order.provider().equals(provider)) {
			throw new PaymentEventMismatchException("provider");
		}
		if (order.amount().compareTo(event.amount()) != 0) {
			throw new PaymentEventMismatchException("amount");
		}
		if (!order.currency().equals(event.currency())) {
			throw new PaymentEventMismatchException("currency");
		}
	}

	private static String sha256(byte[] body) {
		try {
			return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(body));
		}
		catch (NoSuchAlgorithmException exception) {
			throw new IllegalStateException("SHA-256 is unavailable", exception);
		}
	}

	private static String coveragePayload(PaymentOrder order, String status) {
		return "{\"orderId\":\"%s\",\"workerPhone\":\"%s\",\"status\":\"%s\"}"
				.formatted(order.id(), order.workerPhone(), status);
	}
}
