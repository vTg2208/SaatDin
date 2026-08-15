package com.saatdin.billing.order;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

@Validated
@RestController
@RequestMapping("/internal/v1/payment-orders")
public class PaymentOrderController {

	private final PaymentOrderService orderService;
	private final PaymentOrderQueryService queryService;

	public PaymentOrderController(PaymentOrderService orderService, PaymentOrderQueryService queryService) {
		this.orderService = orderService;
		this.queryService = queryService;
	}

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public PaymentOrderView create(
			@Valid @RequestBody PaymentOrderRequest request,
			@RequestHeader("Idempotency-Key") @NotBlank @Size(max = 120) String idempotencyKey) {
		return PaymentOrderView.from(orderService.create(request.toCommand(), idempotencyKey));
	}

	@GetMapping("/{orderId}")
	public PaymentOrderView get(
			@PathVariable UUID orderId,
			@RequestParam @NotBlank @Size(max = 20) String workerPhone) {
		return PaymentOrderView.from(queryService.getOwned(orderId, workerPhone));
	}
}
