package com.saatdin.billing.coverage;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import com.saatdin.billing.order.PaymentOrder;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "coverage_periods", schema = "billing")
public class CoveragePeriod {

	@Id private UUID id;
	@Column(name = "worker_phone", nullable = false, length = 15) private String workerPhone;
	@Column(name = "payment_order_id", nullable = false, unique = true) private UUID paymentOrderId;
	@Column(name = "plan_code", nullable = false, length = 40) private String planCode;
	@Column(name = "starts_on", nullable = false) private LocalDate startsOn;
	@Column(name = "ends_on", nullable = false) private LocalDate endsOn;
	@Enumerated(EnumType.STRING) @Column(nullable = false, length = 24) private CoverageStatus status;
	@Column(name = "activated_at", nullable = false) private Instant activatedAt;
	@Column(name = "revoked_at") private Instant revokedAt;

	protected CoveragePeriod() {
	}

	public static CoveragePeriod activate(PaymentOrder order, Instant at) {
		CoveragePeriod coverage = new CoveragePeriod();
		coverage.id = UUID.randomUUID();
		coverage.workerPhone = order.workerPhone();
		coverage.paymentOrderId = order.id();
		coverage.planCode = order.planCode();
		coverage.startsOn = order.coverageWeekStart();
		coverage.endsOn = order.coverageWeekStart().plusDays(6);
		coverage.status = CoverageStatus.ACTIVE;
		coverage.activatedAt = at;
		return coverage;
	}

	public void revoke(Instant at) {
		status = CoverageStatus.REVOKED;
		revokedAt = at;
	}

	public String workerPhone() { return workerPhone; }
	public String planCode() { return planCode; }
	public LocalDate startsOn() { return startsOn; }
	public LocalDate endsOn() { return endsOn; }
	public CoverageStatus status() { return status; }
}
