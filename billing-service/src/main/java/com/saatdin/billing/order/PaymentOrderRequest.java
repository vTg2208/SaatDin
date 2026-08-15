package com.saatdin.billing.order;

import java.math.BigDecimal;
import java.time.LocalDate;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record PaymentOrderRequest(
		@NotBlank @Size(max = 20) String workerPhone,
		@NotBlank @Size(max = 40) String planCode,
		@NotNull @DecimalMin(value = "0.01") @Digits(integer = 10, fraction = 2) BigDecimal amount,
		@NotBlank @Pattern(regexp = "(?i)INR") String currency,
		@NotNull LocalDate coverageWeekStart) {

	CreatePaymentOrderCommand toCommand() {
		return new CreatePaymentOrderCommand(workerPhone, planCode, amount, currency, coverageWeekStart);
	}
}
