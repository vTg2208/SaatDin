package com.saatdin.billing.payment;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.saatdin.billing.order.PaymentOrder;
import com.saatdin.billing.provider.VerifiedPaymentEvent;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "payment_transactions", schema = "billing")
public class PaymentTransaction {

	@Id private UUID id;
	@Column(name = "payment_order_id", nullable = false) private UUID paymentOrderId;
	@Column(nullable = false, length = 40) private String provider;
	@Column(name = "provider_payment_id", nullable = false, length = 160) private String providerPaymentId;
	@Column(nullable = false, precision = 12, scale = 2) private BigDecimal amount;
	@Column(nullable = false, length = 3) private String currency;
	@Enumerated(EnumType.STRING) @Column(nullable = false, length = 24) private PaymentTransactionStatus status;
	@Column(name = "occurred_at", nullable = false) private Instant occurredAt;
	@Column(name = "created_at", nullable = false, updatable = false) private Instant createdAt;

	protected PaymentTransaction() {
	}

	public static PaymentTransaction captured(
			PaymentOrder order, VerifiedPaymentEvent event, String provider, Instant createdAt) {
		PaymentTransaction transaction = new PaymentTransaction();
		transaction.id = UUID.randomUUID();
		transaction.paymentOrderId = order.id();
		transaction.provider = provider;
		transaction.providerPaymentId = event.providerPaymentId();
		transaction.amount = event.amount();
		transaction.currency = event.currency();
		transaction.status = PaymentTransactionStatus.CAPTURED;
		transaction.occurredAt = event.occurredAt();
		transaction.createdAt = createdAt;
		return transaction;
	}

	public void markRefunded() {
		status = PaymentTransactionStatus.REFUNDED;
	}

	public PaymentTransactionStatus status() { return status; }
	public UUID paymentOrderId() { return paymentOrderId; }
}
