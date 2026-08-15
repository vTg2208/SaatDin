package com.saatdin.billing.provider.sandbox;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Map;
import java.util.Objects;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import com.saatdin.billing.order.PaymentOrderStatus;
import com.saatdin.billing.order.PaymentOrder;
import com.saatdin.billing.provider.InvalidWebhookSignatureException;
import com.saatdin.billing.provider.PaymentProvider;
import com.saatdin.billing.provider.ProviderOrder;
import com.saatdin.billing.provider.VerifiedPaymentEvent;

import tools.jackson.databind.json.JsonMapper;

public final class SandboxPaymentProvider implements PaymentProvider {

	private static final String HMAC_SHA_256 = "HmacSHA256";

	private final byte[] webhookSecret;
	private final JsonMapper jsonMapper;

	public SandboxPaymentProvider(String webhookSecret) {
		this(webhookSecret, JsonMapper.builder().build());
	}

	SandboxPaymentProvider(String webhookSecret, JsonMapper jsonMapper) {
		if (webhookSecret == null || webhookSecret.isBlank()) {
			throw new IllegalArgumentException("sandbox webhook secret is required");
		}
		this.webhookSecret = webhookSecret.getBytes(StandardCharsets.UTF_8);
		this.jsonMapper = Objects.requireNonNull(jsonMapper, "json mapper is required");
	}

	@Override
	public String name() {
		return "sandbox";
	}

	@Override
	public ProviderOrder createOrder(java.util.UUID orderId, java.math.BigDecimal amount, String currency) {
		Objects.requireNonNull(orderId, "order id is required");
		Objects.requireNonNull(amount, "amount is required");
		return new ProviderOrder("sandbox_" + orderId, Map.of("mode", "sandbox"));
	}

	@Override
	public VerifiedPaymentEvent verifyWebhook(String signature, byte[] body) {
		byte[] payload = Objects.requireNonNull(body, "webhook body is required");
		if (!signatureMatches(signature, payload)) {
			throw new InvalidWebhookSignatureException();
		}

		try {
			SandboxWebhookPayload parsed = jsonMapper.readValue(payload, SandboxWebhookPayload.class);
			return new VerifiedPaymentEvent(
					parsed.providerEventId(),
					parsed.providerPaymentId(),
					parsed.orderId(),
					PaymentOrderStatus.valueOf(parsed.status()),
					parsed.amount(),
					parsed.currency(),
					Instant.parse(parsed.occurredAt()));
		}
		catch (Exception exception) {
			throw new IllegalArgumentException(
					"sandbox webhook payload is invalid: " + exception.getMessage(), exception);
		}
	}

	public SandboxWebhook createPaidWebhook(PaymentOrder order, Instant occurredAt) {
		Objects.requireNonNull(order, "payment order is required");
		try {
			byte[] body = jsonMapper.writeValueAsBytes(new SandboxWebhookPayload(
					"sandbox-event-" + order.id(),
					"sandbox-payment-" + order.id(),
					order.id(),
					PaymentOrderStatus.PAID.name(),
					order.amount(),
					order.currency(),
					occurredAt.toString()));
			Mac mac = Mac.getInstance(HMAC_SHA_256);
			mac.init(new SecretKeySpec(webhookSecret, HMAC_SHA_256));
			return new SandboxWebhook(HexFormat.of().formatHex(mac.doFinal(body)), body);
		}
		catch (Exception exception) {
			throw new IllegalStateException("could not create sandbox payment event", exception);
		}
	}

	private boolean signatureMatches(String signature, byte[] body) {
		try {
			byte[] supplied = HexFormat.of().parseHex(Objects.requireNonNullElse(signature, ""));
			Mac mac = Mac.getInstance(HMAC_SHA_256);
			mac.init(new SecretKeySpec(webhookSecret, HMAC_SHA_256));
			return MessageDigest.isEqual(mac.doFinal(body), supplied);
		}
		catch (IllegalArgumentException | GeneralSecurityException exception) {
			return false;
		}
	}

	private record SandboxWebhookPayload(
			String providerEventId,
			String providerPaymentId,
			java.util.UUID orderId,
			String status,
			java.math.BigDecimal amount,
			String currency,
			String occurredAt) {
	}

	public record SandboxWebhook(String signature, byte[] body) {
		public SandboxWebhook {
			body = body.clone();
		}

		@Override
		public byte[] body() {
			return body.clone();
		}
	}
}
