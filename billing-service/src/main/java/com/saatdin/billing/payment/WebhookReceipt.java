package com.saatdin.billing.payment;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "webhook_receipts", schema = "billing")
public class WebhookReceipt {

	@Id private UUID id;
	@Column(nullable = false, length = 40) private String provider;
	@Column(name = "provider_event_id", nullable = false, length = 160) private String providerEventId;
	@Column(name = "payload_sha256", nullable = false, length = 64) private String payloadSha256;
	@Enumerated(EnumType.STRING) @Column(nullable = false, length = 24) private WebhookReceiptStatus status;
	@Column(name = "received_at", nullable = false) private Instant receivedAt;
	@Column(name = "processed_at") private Instant processedAt;

	protected WebhookReceipt() {
	}

	public static WebhookReceipt received(String provider, String eventId, String payloadSha256, Instant receivedAt) {
		WebhookReceipt receipt = new WebhookReceipt();
		receipt.id = UUID.randomUUID();
		receipt.provider = provider;
		receipt.providerEventId = eventId;
		receipt.payloadSha256 = payloadSha256;
		receipt.status = WebhookReceiptStatus.RECEIVED;
		receipt.receivedAt = receivedAt;
		return receipt;
	}

	public void markProcessed(Instant at) {
		status = WebhookReceiptStatus.PROCESSED;
		processedAt = at;
	}
}
