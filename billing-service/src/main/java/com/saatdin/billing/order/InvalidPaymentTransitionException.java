package com.saatdin.billing.order;

public final class InvalidPaymentTransitionException extends RuntimeException {

	public InvalidPaymentTransitionException(PaymentOrderStatus from, PaymentOrderStatus to) {
		super("Payment order cannot transition from " + from + " to " + to);
	}
}
