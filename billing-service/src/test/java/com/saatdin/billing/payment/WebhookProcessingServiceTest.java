package com.saatdin.billing.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.saatdin.billing.coverage.CoveragePeriod;
import com.saatdin.billing.coverage.CoveragePeriodRepository;
import com.saatdin.billing.order.PaymentOrder;
import com.saatdin.billing.order.PaymentOrderRepository;
import com.saatdin.billing.order.PaymentOrderStatus;
import com.saatdin.billing.outbox.OutboxEvent;
import com.saatdin.billing.outbox.OutboxEventRepository;
import com.saatdin.billing.provider.PaymentProvider;
import com.saatdin.billing.provider.VerifiedPaymentEvent;
import com.saatdin.billing.provider.InvalidWebhookSignatureException;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;

@ExtendWith(MockitoExtension.class)
class WebhookProcessingServiceTest {

	private static final Instant NOW = Instant.parse("2026-08-15T08:00:00Z");
	private static final UUID ORDER_ID = UUID.fromString("63c40536-b23a-4d52-8360-1a08454dcd10");

	@Mock private PaymentProvider provider;
	@Mock private PaymentOrderRepository orderRepository;
	@Mock private PaymentTransactionRepository transactionRepository;
	@Mock private WebhookReceiptRepository receiptRepository;
	@Mock private CoveragePeriodRepository coverageRepository;
	@Mock private OutboxEventRepository outboxRepository;

	private SimpleMeterRegistry meterRegistry;
	private WebhookProcessingService service;

	@BeforeEach
	void setUp() {
		meterRegistry = new SimpleMeterRegistry();
		when(provider.name()).thenReturn("sandbox");
		service = new WebhookProcessingService(
				List.of(provider), orderRepository, transactionRepository, receiptRepository,
				coverageRepository, outboxRepository, new BillingMetrics(meterRegistry),
				Clock.fixed(NOW, ZoneOffset.UTC));
	}

	@Test
	void paidEventCreatesOneLedgerTransactionCoverageReceiptAndOutboxEvent() {
		PaymentOrder order = pendingOrder();
		when(provider.verifyWebhook("signature", new byte[] { 1, 2, 3 })).thenReturn(paidEvent());
		when(receiptRepository.findByProviderAndProviderEventId("sandbox", "evt-100"))
				.thenReturn(Optional.empty());
		when(orderRepository.findByIdForUpdate(ORDER_ID)).thenReturn(Optional.of(order));

		WebhookResult result = service.process("sandbox", "signature", new byte[] { 1, 2, 3 });

		assertThat(result).isEqualTo(WebhookResult.PROCESSED);
		assertThat(order.status()).isEqualTo(PaymentOrderStatus.PAID);
		verify(transactionRepository).save(any(PaymentTransaction.class));
		ArgumentCaptor<CoveragePeriod> coverage = ArgumentCaptor.forClass(CoveragePeriod.class);
		verify(coverageRepository).save(coverage.capture());
		assertThat(coverage.getValue().startsOn()).isEqualTo(LocalDate.of(2026, 8, 17));
		assertThat(coverage.getValue().endsOn()).isEqualTo(LocalDate.of(2026, 8, 23));
		verify(receiptRepository).save(any(WebhookReceipt.class));
		ArgumentCaptor<OutboxEvent> outbox = ArgumentCaptor.forClass(OutboxEvent.class);
		verify(outboxRepository).save(outbox.capture());
		assertThat(outbox.getValue().eventType()).isEqualTo("coverage.activated");
		assertThat(meterRegistry.counter("billing.payments.paid").count()).isEqualTo(1.0);
	}

	@Test
	void duplicateProviderEventDoesNotRepeatWrites() {
		when(provider.verifyWebhook("signature", new byte[] { 1 })).thenReturn(paidEvent());
		when(receiptRepository.findByProviderAndProviderEventId("sandbox", "evt-100"))
				.thenReturn(Optional.of(WebhookReceipt.received("sandbox", "evt-100", "0".repeat(64), NOW)));

		WebhookResult result = service.process("sandbox", "signature", new byte[] { 1 });

		assertThat(result).isEqualTo(WebhookResult.DUPLICATE);
		verify(orderRepository, never()).findByIdForUpdate(any());
		verify(transactionRepository, never()).save(any());
		verify(coverageRepository, never()).save(any());
		verify(outboxRepository, never()).save(any());
		assertThat(meterRegistry.counter("billing.webhooks.duplicate").count()).isEqualTo(1.0);
	}

	@Test
	void amountMismatchRejectsAllLedgerWrites() {
		VerifiedPaymentEvent mismatch = new VerifiedPaymentEvent(
				"evt-100", "pay-100", ORDER_ID, PaymentOrderStatus.PAID,
				new BigDecimal("74.00"), "INR", NOW.minusSeconds(10));
		when(provider.verifyWebhook("signature", new byte[] { 1 })).thenReturn(mismatch);
		when(receiptRepository.findByProviderAndProviderEventId("sandbox", "evt-100"))
				.thenReturn(Optional.empty());
		when(orderRepository.findByIdForUpdate(ORDER_ID)).thenReturn(Optional.of(pendingOrder()));

		assertThatThrownBy(() -> service.process("sandbox", "signature", new byte[] { 1 }))
				.isInstanceOf(PaymentEventMismatchException.class);
		verify(transactionRepository, never()).save(any());
		verify(receiptRepository, never()).save(any());
		verify(coverageRepository, never()).save(any());
		verify(outboxRepository, never()).save(any());
	}

	@Test
	void failedEventMarksOrderFailedWithoutCreatingCoverage() {
		PaymentOrder order = pendingOrder();
		VerifiedPaymentEvent failed = event(PaymentOrderStatus.FAILED);
		when(provider.verifyWebhook("signature", new byte[] { 1 })).thenReturn(failed);
		when(receiptRepository.findByProviderAndProviderEventId("sandbox", "evt-100"))
				.thenReturn(Optional.empty());
		when(orderRepository.findByIdForUpdate(ORDER_ID)).thenReturn(Optional.of(order));

		assertThat(service.process("sandbox", "signature", new byte[] { 1 }))
				.isEqualTo(WebhookResult.PROCESSED);
		assertThat(order.status()).isEqualTo(PaymentOrderStatus.FAILED);
		verify(transactionRepository, never()).save(any());
		verify(coverageRepository, never()).save(any());
		assertThat(meterRegistry.counter("billing.payments.failed").count()).isEqualTo(1.0);
	}

	@Test
	void refundedEventRevokesCoverageAndUpdatesCapturedTransaction() {
		PaymentOrder order = pendingOrder();
		order.markPaid(NOW.minusSeconds(120));
		VerifiedPaymentEvent refunded = event(PaymentOrderStatus.REFUNDED);
		PaymentTransaction transaction = PaymentTransaction.captured(order, paidEvent(), "sandbox", NOW.minusSeconds(120));
		CoveragePeriod coverage = CoveragePeriod.activate(order, NOW.minusSeconds(120));
		when(provider.verifyWebhook("signature", new byte[] { 1 })).thenReturn(refunded);
		when(receiptRepository.findByProviderAndProviderEventId("sandbox", "evt-100"))
				.thenReturn(Optional.empty());
		when(orderRepository.findByIdForUpdate(ORDER_ID)).thenReturn(Optional.of(order));
		when(transactionRepository.findByProviderAndProviderPaymentId("sandbox", "pay-100"))
				.thenReturn(Optional.of(transaction));
		when(coverageRepository.findByPaymentOrderId(ORDER_ID)).thenReturn(Optional.of(coverage));

		assertThat(service.process("sandbox", "signature", new byte[] { 1 }))
				.isEqualTo(WebhookResult.PROCESSED);
		assertThat(order.status()).isEqualTo(PaymentOrderStatus.REFUNDED);
		assertThat(transaction.status()).isEqualTo(PaymentTransactionStatus.REFUNDED);
		assertThat(coverage.status()).isEqualTo(com.saatdin.billing.coverage.CoverageStatus.REVOKED);
		ArgumentCaptor<OutboxEvent> outbox = ArgumentCaptor.forClass(OutboxEvent.class);
		verify(outboxRepository).save(outbox.capture());
		assertThat(outbox.getValue().eventType()).isEqualTo("coverage.revoked");
	}

	@Test
	void invalidSignatureIsCountedBeforeRepositoryAccess() {
		when(provider.verifyWebhook("bad", new byte[] { 1 })).thenThrow(new InvalidWebhookSignatureException());

		assertThatThrownBy(() -> service.process("sandbox", "bad", new byte[] { 1 }))
				.isInstanceOf(InvalidWebhookSignatureException.class);
		verify(receiptRepository, never()).acquireEventLock(any());
		assertThat(meterRegistry.counter("billing.webhooks.signature-failed").count()).isEqualTo(1.0);
	}

	private static PaymentOrder pendingOrder() {
		PaymentOrder order = PaymentOrder.create(
				ORDER_ID, "9876543210", "standard", new BigDecimal("75.00"), "INR",
				LocalDate.of(2026, 8, 17), "sandbox", "checkout-123",
				NOW.plusSeconds(900), NOW.minusSeconds(300));
		order.markPending(NOW.minusSeconds(240), "sandbox_" + ORDER_ID);
		return order;
	}

	private static VerifiedPaymentEvent paidEvent() {
		return event(PaymentOrderStatus.PAID);
	}

	private static VerifiedPaymentEvent event(PaymentOrderStatus status) {
		return new VerifiedPaymentEvent(
				"evt-100", "pay-100", ORDER_ID, status,
				new BigDecimal("75.00"), "INR", NOW.minusSeconds(10));
	}
}
