package com.saatdin.billing.coverage;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CoveragePeriodRepository extends JpaRepository<CoveragePeriod, UUID> {

	@Query("""
			select coverage from CoveragePeriod coverage
			where coverage.workerPhone = :phone
			  and coverage.status = com.saatdin.billing.coverage.CoverageStatus.ACTIVE
			  and coverage.startsOn <= :at and coverage.endsOn >= :at
			""")
	Optional<CoveragePeriod> findActive(@Param("phone") String workerPhone, @Param("at") LocalDate at);

	Optional<CoveragePeriod> findByPaymentOrderId(UUID paymentOrderId);
}
