package com.saatdin.billing.provider;

import java.util.Map;
import java.util.Objects;

public record ProviderOrder(String providerOrderId, Map<String, Object> checkoutData) {

	public ProviderOrder {
		if (providerOrderId == null || providerOrderId.isBlank()) {
			throw new IllegalArgumentException("provider order id is required");
		}
		checkoutData = Map.copyOf(Objects.requireNonNull(checkoutData, "checkout data is required"));
	}
}
