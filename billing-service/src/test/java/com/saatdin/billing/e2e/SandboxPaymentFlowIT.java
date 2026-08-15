package com.saatdin.billing.e2e;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import com.saatdin.billing.coverage.CoveragePeriodRepository;
import com.saatdin.billing.coverage.CoverageQueryService;
import com.saatdin.billing.order.CreatePaymentOrderCommand;
import com.saatdin.billing.order.PaymentOrder;
import com.saatdin.billing.order.PaymentOrderService;
import com.saatdin.billing.payment.PaymentTransactionRepository;
import com.saatdin.billing.payment.WebhookProcessingService;
import com.saatdin.billing.payment.WebhookResult;
import com.saatdin.billing.provider.sandbox.SandboxPaymentProvider;
import com.saatdin.billing.provider.sandbox.SandboxPaymentProvider.SandboxWebhook;

@Testcontainers(disabledWithoutDocker = true)
@ActiveProfiles("sandbox")
@SpringBootTest(properties = {
		"billing.internal-api-key=0123456789abcdef0123456789abcdef",
		"billing.sandbox-webhook-secret=e2e-sandbox-secret"
})
class SandboxPaymentFlowIT {

	@Container
	@ServiceConnection
	static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:17-alpine");

	@Autowired private PaymentOrderService orderService;
	@Autowired private SandboxPaymentProvider provider;
	@Autowired private WebhookProcessingService webhookService;
	@Autowired private CoverageQueryService coverageQueryService;
	@Autowired private PaymentTransactionRepository transactionRepository;
	@Autowired private CoveragePeriodRepository coverageRepository;
	@Autowired private Clock clock;

	@Test
	void paidSandboxOrderActivatesCoverageExactlyOnce() {
		PaymentOrder order = orderService.create(new CreatePaymentOrderCommand(
				"9876543210", "standard", new BigDecimal("75.00"), "INR",
				LocalDate.of(2026, 8, 17)), "e2e-checkout-1");
		SandboxWebhook webhook = provider.createPaidWebhook(order, clock.instant());

		assertThat(webhookService.process("sandbox", webhook.signature(), webhook.body()))
				.isEqualTo(WebhookResult.PROCESSED);
		assertThat(webhookService.process("sandbox", webhook.signature(), webhook.body()))
				.isEqualTo(WebhookResult.DUPLICATE);

		assertThat(coverageQueryService.findCoverage("9876543210", LocalDate.of(2026, 8, 17)).active())
				.isTrue();
		assertThat(transactionRepository.count()).isEqualTo(1);
		assertThat(coverageRepository.count()).isEqualTo(1);
	}
}
