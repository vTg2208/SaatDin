package com.saatdin.billing.provider;

public class InvalidWebhookSignatureException extends RuntimeException {

	public InvalidWebhookSignatureException() {
		super("webhook signature is invalid");
	}
}
