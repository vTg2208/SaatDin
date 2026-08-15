package com.saatdin.billing.provider;

import java.math.BigDecimal;
import java.util.UUID;

public interface PaymentProvider {

	String name();

	ProviderOrder createOrder(UUID orderId, BigDecimal amount, String currency);

	VerifiedPaymentEvent verifyWebhook(String signature, byte[] body);
}
