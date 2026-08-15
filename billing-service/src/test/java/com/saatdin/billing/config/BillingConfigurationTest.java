package com.saatdin.billing.config;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

class BillingConfigurationTest {

	@Test
	void productionRejectsShortInternalApiKey() {
		BillingProperties properties = new BillingProperties(
				"too-short-for-production", "razorpay", "", 100, "production");

		assertThatThrownBy(() -> new BillingConfiguration(properties, new MockEnvironment()).validateEnvironment())
				.isInstanceOf(IllegalStateException.class)
				.hasMessageContaining("32 characters");
	}

	@Test
	void productionRejectsSandboxProvider() {
		BillingProperties properties = new BillingProperties(
				"0123456789abcdef0123456789abcdef", "sandbox", "secret", 100, "production");

		assertThatThrownBy(() -> new BillingConfiguration(properties, new MockEnvironment()).validateEnvironment())
				.isInstanceOf(IllegalStateException.class)
				.hasMessageContaining("forbidden");
	}

	@Test
	void productionAcceptsNonSandboxProviderWithoutSandboxSecret() {
		BillingProperties properties = new BillingProperties(
				"0123456789abcdef0123456789abcdef", "razorpay", "", 100, "production");

		assertThatCode(() -> new BillingConfiguration(properties, new MockEnvironment()).validateEnvironment())
				.doesNotThrowAnyException();
	}

	@Test
	void productionRejectsSandboxProfileEvenWithRealProvider() {
		BillingProperties properties = new BillingProperties(
				"0123456789abcdef0123456789abcdef", "razorpay", "", 100, "production");
		MockEnvironment environment = new MockEnvironment();
		environment.setActiveProfiles("sandbox");

		assertThatThrownBy(() -> new BillingConfiguration(properties, environment).validateEnvironment())
				.isInstanceOf(IllegalStateException.class)
				.hasMessageContaining("profile");
	}
}
