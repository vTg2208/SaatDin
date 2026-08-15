package com.saatdin.billing.order;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.Locale;
import java.util.Objects;

public record CreatePaymentOrderCommand(
		String workerPhone,
		String planCode,
		BigDecimal amount,
		String currency,
		LocalDate coverageWeekStart) {

	public CreatePaymentOrderCommand {
		workerPhone = WorkerPhone.normalize(workerPhone);
		if (planCode == null || planCode.isBlank()) {
			throw new IllegalArgumentException("plan code is required");
		}
		planCode = planCode.trim().toLowerCase(Locale.ROOT);
		if (planCode.length() > 40) {
			throw new IllegalArgumentException("plan code must not exceed 40 characters");
		}
		if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0 || amount.stripTrailingZeros().scale() > 2) {
			throw new IllegalArgumentException("amount must be positive with at most two decimal places");
		}
		currency = Objects.requireNonNull(currency, "currency is required").trim().toUpperCase(Locale.ROOT);
		if (!"INR".equals(currency)) {
			throw new IllegalArgumentException("currency must be INR");
		}
		if (coverageWeekStart == null || coverageWeekStart.getDayOfWeek() != DayOfWeek.MONDAY) {
			throw new IllegalArgumentException("coverage week must start on Monday");
		}
	}
}
