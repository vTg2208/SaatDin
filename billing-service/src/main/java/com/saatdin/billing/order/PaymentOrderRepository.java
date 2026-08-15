package com.saatdin.billing.order;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

public interface PaymentOrderRepository extends JpaRepository<PaymentOrder, UUID> {

	@Query(value = "select pg_advisory_xact_lock(hashtextextended(:key, 0))", nativeQuery = true)
	void acquireIdempotencyLock(@Param("key") String idempotencyKey);

	Optional<PaymentOrder> findByIdempotencyKey(String idempotencyKey);

	Optional<PaymentOrder> findByIdAndWorkerPhone(UUID id, String workerPhone);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select paymentOrder from PaymentOrder paymentOrder where paymentOrder.id = :id")
	Optional<PaymentOrder> findByIdForUpdate(@Param("id") UUID id);
}
