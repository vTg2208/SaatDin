package com.saatdin.billing.config;

import java.time.Clock;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;

import com.saatdin.billing.provider.sandbox.SandboxPaymentProvider;

import jakarta.annotation.PostConstruct;

@Configuration
@EnableConfigurationProperties(BillingProperties.class)
public class BillingConfiguration {

	private final BillingProperties properties;
	private final Environment environment;

	public BillingConfiguration(BillingProperties properties, Environment environment) {
		this.properties = properties;
		this.environment = environment;
	}

	@PostConstruct
	void validateEnvironment() {
		if (properties.production() && properties.internalApiKey().length() < 32) {
			throw new IllegalStateException("production billing internal API key must contain at least 32 characters");
		}
		if (properties.production() && "sandbox".equalsIgnoreCase(properties.provider())) {
			throw new IllegalStateException("sandbox billing provider is forbidden in production");
		}
		if (properties.production()) {
			for (String profile : environment.getActiveProfiles()) {
				if ("sandbox".equalsIgnoreCase(profile)) {
					throw new IllegalStateException("sandbox profile is forbidden in production");
				}
			}
		}
	}

	@Bean
	Clock billingClock() {
		return Clock.systemUTC();
	}

	@Bean
	@Profile("sandbox")
	SandboxPaymentProvider sandboxPaymentProvider() {
		return new SandboxPaymentProvider(properties.sandboxWebhookSecret());
	}
}
