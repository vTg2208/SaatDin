package com.saatdin.billing.api;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import com.saatdin.billing.order.CreatePaymentOrderCommand;
import com.saatdin.billing.order.PaymentOrder;
import com.saatdin.billing.order.PaymentOrderController;
import com.saatdin.billing.order.PaymentOrderQueryService;
import com.saatdin.billing.order.PaymentOrderService;
import com.saatdin.billing.shared.ApiExceptionHandler;

@ExtendWith(MockitoExtension.class)
class PaymentOrderControllerTest {

	@Mock private PaymentOrderService orderService;
	@Mock private PaymentOrderQueryService queryService;
	private MockMvc mvc;

	@BeforeEach
	void setUp() {
		mvc = MockMvcBuilders.standaloneSetup(new PaymentOrderController(orderService, queryService))
				.setControllerAdvice(new ApiExceptionHandler())
				.build();
	}

	@Test
	void createsOrderFromAuthoritativeInternalRequest() throws Exception {
		when(orderService.create(any(), any())).thenReturn(pendingOrder());

		mvc.perform(post("/internal/v1/payment-orders")
				.header("Idempotency-Key", "checkout-123")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"workerPhone":"9876543210","planCode":"standard","amount":75.00,
						 "currency":"INR","coverageWeekStart":"2026-08-17"}
						"""))
				.andExpect(status().isCreated())
				.andExpect(jsonPath("$.orderId").value("63c40536-b23a-4d52-8360-1a08454dcd10"))
				.andExpect(jsonPath("$.status").value("PENDING"))
				.andExpect(jsonPath("$.amount").value(75.00))
				.andExpect(jsonPath("$.checkoutData.providerOrderId").value("sandbox-order-1"));

		verify(orderService).create(any(CreatePaymentOrderCommand.class), org.mockito.ArgumentMatchers.eq("checkout-123"));
	}

	@Test
	void rejectsMissingIdempotencyKey() throws Exception {
		mvc.perform(post("/internal/v1/payment-orders")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"workerPhone":"9876543210","planCode":"standard","amount":75.00,
						 "currency":"INR","coverageWeekStart":"2026-08-17"}
						"""))
				.andExpect(status().isBadRequest());
	}

	private static PaymentOrder pendingOrder() {
		Instant now = Instant.parse("2026-08-15T08:00:00Z");
		PaymentOrder order = PaymentOrder.create(
				UUID.fromString("63c40536-b23a-4d52-8360-1a08454dcd10"),
				"9876543210", "standard", new BigDecimal("75.00"), "INR",
				LocalDate.of(2026, 8, 17), "sandbox", "checkout-123", now.plusSeconds(900), now);
		order.markPending(now, "sandbox-order-1");
		return order;
	}
}
