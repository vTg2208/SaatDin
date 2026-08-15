package com.saatdin.billing.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
class BillingSchemaIT {

	@Container
	@ServiceConnection
	static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:17-alpine");

	@Autowired
	private JdbcTemplate jdbc;

	@Test
	void flywayCreatesAllOwnedTables() {
		Integer count = jdbc.queryForObject("""
				select count(*) from information_schema.tables
				where table_schema = 'billing'
				  and table_name in ('payment_orders', 'payment_transactions',
				    'coverage_periods', 'webhook_receipts', 'outbox_events')
				""", Integer.class);

		assertThat(count).isEqualTo(5);
	}
}
