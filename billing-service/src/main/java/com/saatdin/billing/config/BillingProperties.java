package com.saatdin.billing.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

@Validated
@ConfigurationProperties(prefix = "billing")
public record BillingProperties(
		@NotBlank @Size(min = 16, max = 256) String internalApiKey,
		@NotBlank @Size(max = 40) String provider,
		@Size(max = 256) String sandboxWebhookSecret,
		@Min(1) @Max(500) int coverageMaxBatchSize,
		@NotBlank String appEnvironment) {

	public boolean production() {
		return "production".equalsIgnoreCase(appEnvironment);
	}
}
