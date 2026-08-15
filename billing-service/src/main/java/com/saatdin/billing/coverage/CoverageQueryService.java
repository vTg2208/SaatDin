package com.saatdin.billing.coverage;

import java.time.LocalDate;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.saatdin.billing.order.WorkerPhone;
import com.saatdin.billing.payment.BillingMetrics;

@Service
public class CoverageQueryService {
	private final CoveragePeriodRepository repository;
	private final BillingMetrics metrics;

	public CoverageQueryService(CoveragePeriodRepository repository, BillingMetrics metrics) {
		this.repository = repository;
		this.metrics = metrics;
	}

	@Transactional(readOnly = true)
	public CoverageView findCoverage(String phone, LocalDate at) {
		String normalized = WorkerPhone.normalize(phone);
		return metrics.timeCoverageQuery(() -> repository.findActive(normalized, at)
				.map(CoverageView::active).orElseGet(CoverageView::inactive));
	}
}
