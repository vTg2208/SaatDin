package com.saatdin.billing.order;

import java.util.UUID;

public class PaymentOrderNotFoundException extends RuntimeException {

	public PaymentOrderNotFoundException(UUID orderId) {
		super("payment order not found: " + orderId);
	}
}
