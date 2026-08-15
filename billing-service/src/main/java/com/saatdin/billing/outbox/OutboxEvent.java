package com.saatdin.billing.outbox;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "outbox_events", schema = "billing")
public class OutboxEvent {

	@Id private UUID id;
	@Column(name = "aggregate_type", nullable = false, length = 80) private String aggregateType;
	@Column(name = "aggregate_id", nullable = false) private UUID aggregateId;
	@Column(name = "event_type", nullable = false, length = 120) private String eventType;
	@JdbcTypeCode(SqlTypes.JSON) @Column(nullable = false, columnDefinition = "jsonb") private String payload;
	@Column(name = "created_at", nullable = false) private Instant createdAt;
	@Column(name = "published_at") private Instant publishedAt;

	protected OutboxEvent() {
	}

	public static OutboxEvent coverage(UUID orderId, String eventType, String payload, Instant at) {
		OutboxEvent event = new OutboxEvent();
		event.id = UUID.randomUUID();
		event.aggregateType = "payment_order";
		event.aggregateId = orderId;
		event.eventType = eventType;
		event.payload = payload;
		event.createdAt = at;
		return event;
	}

	public String eventType() { return eventType; }
}
