package com.saatdin.billing.payment;

public class PaymentEventMismatchException extends RuntimeException {
	public PaymentEventMismatchException(String detail) {
		super("verified payment event does not match order: " + detail);
	}
}
