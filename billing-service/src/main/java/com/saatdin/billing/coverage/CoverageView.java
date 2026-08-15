package com.saatdin.billing.coverage;

import java.time.LocalDate;

public record CoverageView(boolean active, String planCode, LocalDate startsOn, LocalDate endsOn) {
	public static CoverageView inactive() { return new CoverageView(false, null, null, null); }
	public static CoverageView active(CoveragePeriod period) {
		return new CoverageView(true, period.planCode(), period.startsOn(), period.endsOn());
	}
}
