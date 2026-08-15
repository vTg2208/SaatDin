package com.saatdin.billing.payment;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WebhookReceiptRepository extends JpaRepository<WebhookReceipt, UUID> {

	@Query(value = "select pg_advisory_xact_lock(hashtextextended(:key, 0))", nativeQuery = true)
	void acquireEventLock(@Param("key") String key);

	Optional<WebhookReceipt> findByProviderAndProviderEventId(String provider, String providerEventId);
}
