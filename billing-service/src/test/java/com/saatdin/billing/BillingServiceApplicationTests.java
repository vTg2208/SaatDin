package com.saatdin.billing;

import java.time.Clock;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import com.saatdin.billing.order.PaymentOrderRepository;
import com.saatdin.billing.provider.PaymentProvider;

@SpringBootTest(properties = {
		"spring.autoconfigure.exclude="
				+ "org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration,"
				+ "org.springframework.boot.hibernate.autoconfigure.HibernateJpaAutoConfiguration,"
				+ "org.springframework.boot.flyway.autoconfigure.FlywayAutoConfiguration"
})
class BillingServiceApplicationTests {

	@MockitoBean
	private PaymentOrderRepository paymentOrderRepository;

	@MockitoBean
	private PaymentProvider paymentProvider;

	@MockitoBean
	private Clock clock;

	@Test
	void contextLoads() {
	}

}
