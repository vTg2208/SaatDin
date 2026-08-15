package com.saatdin.billing.order;

public final class WorkerPhone {

	private WorkerPhone() {
	}

	public static String normalize(String raw) {
		if (raw == null) {
			throw new IllegalArgumentException("worker phone is required");
		}
		String digits = raw.replaceAll("\\D", "");
		if (digits.length() == 11 && digits.startsWith("0")) {
			digits = digits.substring(1);
		}
		else if (digits.length() == 12 && digits.startsWith("91")) {
			digits = digits.substring(2);
		}
		if (digits.length() != 10) {
			throw new IllegalArgumentException("worker phone must be a valid 10-digit Indian number");
		}
		return digits;
	}
}
