package com.saatdin.billing.shared;

import java.net.URI;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.saatdin.billing.order.IdempotencyConflictException;
import com.saatdin.billing.order.InvalidPaymentTransitionException;
import com.saatdin.billing.order.PaymentOrderNotFoundException;
import com.saatdin.billing.payment.PaymentEventMismatchException;
import com.saatdin.billing.provider.InvalidWebhookSignatureException;

@RestControllerAdvice
public class ApiExceptionHandler {

	@ExceptionHandler(PaymentOrderNotFoundException.class)
	ProblemDetail notFound(RuntimeException exception) {
		return problem(HttpStatus.NOT_FOUND, "Payment order not found", exception);
	}

	@ExceptionHandler({ IdempotencyConflictException.class, InvalidPaymentTransitionException.class,
			PaymentEventMismatchException.class })
	ProblemDetail conflict(RuntimeException exception) {
		return problem(HttpStatus.CONFLICT, "Billing conflict", exception);
	}

	@ExceptionHandler(InvalidWebhookSignatureException.class)
	ProblemDetail unauthorized(RuntimeException exception) {
		return problem(HttpStatus.UNAUTHORIZED, "Invalid webhook signature", exception);
	}

	@ExceptionHandler(IllegalArgumentException.class)
	ProblemDetail badRequest(RuntimeException exception) {
		return problem(HttpStatus.BAD_REQUEST, "Invalid billing request", exception);
	}

	private static ProblemDetail problem(HttpStatus status, String title, RuntimeException exception) {
		ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, exception.getMessage());
		problem.setTitle(title);
		problem.setType(URI.create("https://saatdin.example/problems/" + status.value()));
		return problem;
	}
}
