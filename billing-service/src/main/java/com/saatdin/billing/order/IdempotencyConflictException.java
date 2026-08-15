package com.saatdin.billing.order;

public class IdempotencyConflictException extends RuntimeException {

	public IdempotencyConflictException() {
		super("idempotency key was already used for a different payment order request");
	}
}
