package com.saatdin.billing;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import com.saatdin.billing.order.PaymentOrderRepository;
import com.saatdin.billing.coverage.CoveragePeriodRepository;
import com.saatdin.billing.outbox.OutboxEventRepository;
import com.saatdin.billing.payment.PaymentTransactionRepository;
import com.saatdin.billing.payment.WebhookReceiptRepository;
import com.saatdin.billing.payment.WebhookProcessingService;
import com.saatdin.billing.provider.PaymentProvider;

@SpringBootTest(properties = {
		"spring.autoconfigure.exclude="
				+ "org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration,"
				+ "org.springframework.boot.hibernate.autoconfigure.HibernateJpaAutoConfiguration,"
				+ "org.springframework.boot.flyway.autoconfigure.FlywayAutoConfiguration"
})
class BillingServiceApplicationTests {

	@Autowired
	private ApplicationContext applicationContext;

	@MockitoBean
	private PaymentOrderRepository paymentOrderRepository;

	@MockitoBean
	private PaymentProvider paymentProvider;

	@MockitoBean
	private Clock clock;

	@MockitoBean
	private PaymentTransactionRepository paymentTransactionRepository;

	@MockitoBean
	private WebhookReceiptRepository webhookReceiptRepository;

	@MockitoBean
	private CoveragePeriodRepository coveragePeriodRepository;

	@MockitoBean
	private OutboxEventRepository outboxEventRepository;

	@MockitoBean
	private WebhookProcessingService webhookProcessingService;

	@Test
	void contextLoads() {
		assertThat(applicationContext.getBeansOfType(UserDetailsService.class)).isEmpty();
	}

}
