package com.saatdin.billing.payment;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentTransactionRepository extends JpaRepository<PaymentTransaction, UUID> {
	Optional<PaymentTransaction> findByProviderAndProviderPaymentId(String provider, String providerPaymentId);
}
