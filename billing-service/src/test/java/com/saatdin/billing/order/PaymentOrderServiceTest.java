package com.saatdin.billing.order;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.saatdin.billing.provider.PaymentProvider;
import com.saatdin.billing.provider.ProviderOrder;
import com.saatdin.billing.payment.BillingMetrics;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;

@ExtendWith(MockitoExtension.class)
class PaymentOrderServiceTest {

	private static final Instant NOW = Instant.parse("2026-08-15T08:00:00Z");
	private static final Clock CLOCK = Clock.fixed(NOW, ZoneOffset.UTC);
	private static final String KEY = "checkout-123";

	@Mock
	private PaymentOrderRepository repository;

	@Mock
	private PaymentProvider provider;

	private PaymentOrderService service;
	private PaymentOrderQueryService queryService;

	@BeforeEach
	void setUp() {
		service = new PaymentOrderService(repository, provider, new BillingMetrics(new SimpleMeterRegistry()), CLOCK);
		queryService = new PaymentOrderQueryService(repository, CLOCK);
	}

	@Test
	void repeatedIdenticalRequestReturnsExistingOrder() {
		AtomicReference<PaymentOrder> persisted = new AtomicReference<>();
		when(provider.name()).thenReturn("sandbox");
		when(provider.createOrder(any(), any(), eq("INR")))
				.thenReturn(new ProviderOrder("sandbox-order-1", Map.of()));
		when(repository.findByIdempotencyKey(KEY))
				.thenAnswer(invocation -> Optional.ofNullable(persisted.get()));
		when(repository.save(any())).thenAnswer(invocation -> {
			PaymentOrder order = invocation.getArgument(0);
			persisted.set(order);
			return order;
		});

		PaymentOrder first = service.create(command(), KEY);
		PaymentOrder second = service.create(command(), KEY);

		assertThat(second.id()).isEqualTo(first.id());
		verify(provider, times(1)).createOrder(any(), any(), eq("INR"));
	}

	@Test
	void changedRequestWithSameKeyIsRejected() {
		when(repository.findByIdempotencyKey(KEY)).thenReturn(Optional.of(createdOrder()));

		CreatePaymentOrderCommand changed = new CreatePaymentOrderCommand(
				"9876543210", "standard", new BigDecimal("99.00"), "INR", LocalDate.of(2026, 8, 17));

		assertThatThrownBy(() -> service.create(changed, KEY))
				.isInstanceOf(IdempotencyConflictException.class);
		verify(provider, never()).createOrder(any(), any(), any());
	}

	@Test
	void normalizesWorkerAndPlanBeforeCreatingOrder() {
		when(provider.name()).thenReturn("sandbox");
		when(provider.createOrder(any(), any(), eq("INR")))
				.thenReturn(new ProviderOrder("sandbox-order-1", Map.of()));
		when(repository.findByIdempotencyKey(KEY)).thenReturn(Optional.empty());
		when(repository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

		PaymentOrder order = service.create(new CreatePaymentOrderCommand(
				"+91 98765-43210", " Standard ", new BigDecimal("75.00"), "inr",
				LocalDate.of(2026, 8, 17)), KEY);

		assertThat(order.workerPhone()).isEqualTo("9876543210");
		assertThat(order.planCode()).isEqualTo("standard");
		assertThat(order.status()).isEqualTo(PaymentOrderStatus.PENDING);
	}

	@Test
	void anotherWorkerCannotReadOrder() {
		UUID id = UUID.randomUUID();
		when(repository.findByIdAndWorkerPhone(id, "9123456789")).thenReturn(Optional.empty());

		assertThatThrownBy(() -> queryService.getOwned(id, "9123456789"))
				.isInstanceOf(PaymentOrderNotFoundException.class);
	}

	@Test
	void overduePendingOrderIsPersistedAsExpired() {
		PaymentOrder order = PaymentOrder.create(
				UUID.randomUUID(), "9876543210", "standard", new BigDecimal("75.00"), "INR",
				LocalDate.of(2026, 8, 17), "sandbox", KEY, NOW, NOW.minusSeconds(900));
		order.markPending(NOW.minusSeconds(60), "sandbox-order-1");
		UUID id = order.id();
		when(repository.findByIdAndWorkerPhone(id, "9876543210")).thenReturn(Optional.of(order));
		when(repository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

		PaymentOrder result = queryService.getOwned(id, "+91 98765 43210");

		assertThat(result.status()).isEqualTo(PaymentOrderStatus.EXPIRED);
		verify(repository).save(order);
	}

	private static CreatePaymentOrderCommand command() {
		return new CreatePaymentOrderCommand(
				"9876543210", "standard", new BigDecimal("75.00"), "INR", LocalDate.of(2026, 8, 17));
	}

	private static PaymentOrder createdOrder() {
		return PaymentOrder.create(
				UUID.fromString("63c40536-b23a-4d52-8360-1a08454dcd10"),
				"9876543210", "standard", new BigDecimal("75.00"), "INR",
				LocalDate.of(2026, 8, 17), "sandbox", KEY, NOW.plusSeconds(900), NOW.minusSeconds(120));
	}
}
