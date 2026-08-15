package com.saatdin.billing.provider.sandbox;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.Test;

import com.saatdin.billing.order.PaymentOrderStatus;
import com.saatdin.billing.provider.InvalidWebhookSignatureException;
import com.saatdin.billing.provider.ProviderOrder;
import com.saatdin.billing.provider.VerifiedPaymentEvent;

class SandboxPaymentProviderTest {

	private static final String SECRET = "test-sandbox-secret";
	private static final UUID ORDER_ID = UUID.fromString("75b78bd4-c25b-4a77-a670-12a6350c4877");
	private final SandboxPaymentProvider provider = new SandboxPaymentProvider(SECRET);

	@Test
	void createsDeterministicProviderOrder() {
		ProviderOrder order = provider.createOrder(ORDER_ID, new BigDecimal("49.00"), "INR");

		assertThat(provider.name()).isEqualTo("sandbox");
		assertThat(order.providerOrderId()).isEqualTo("sandbox_" + ORDER_ID);
		assertThat(order.checkoutData()).containsEntry("mode", "sandbox");
	}

	@Test
	void verifiesAndNormalizesSignedWebhook() throws Exception {
		byte[] body = validBody();

		VerifiedPaymentEvent event = provider.verifyWebhook(sign(body), body);

		assertThat(event.providerEventId()).isEqualTo("evt-100");
		assertThat(event.providerPaymentId()).isEqualTo("pay-100");
		assertThat(event.orderId()).isEqualTo(ORDER_ID);
		assertThat(event.status()).isEqualTo(PaymentOrderStatus.PAID);
		assertThat(event.amount()).isEqualByComparingTo("49.00");
		assertThat(event.currency()).isEqualTo("INR");
		assertThat(event.occurredAt()).isEqualTo(Instant.parse("2026-08-15T07:00:00Z"));
	}

	@Test
	void rejectsInvalidSignatureBeforeParsing() {
		assertThatThrownBy(() -> provider.verifyWebhook("00", validBody()))
				.isInstanceOf(InvalidWebhookSignatureException.class);
	}

	@Test
	void rejectsMalformedPayload() throws Exception {
		byte[] body = "{not-json".getBytes(StandardCharsets.UTF_8);

		assertThatThrownBy(() -> provider.verifyWebhook(sign(body), body))
				.isInstanceOf(IllegalArgumentException.class)
				.hasMessageContaining("payload");
	}

	@Test
	void rejectsUnsupportedStatus() throws Exception {
		byte[] body = new String(validBody(), StandardCharsets.UTF_8)
				.replace("\"PAID\"", "\"CREATED\"")
				.getBytes(StandardCharsets.UTF_8);

		assertThatThrownBy(() -> provider.verifyWebhook(sign(body), body))
				.isInstanceOf(IllegalArgumentException.class)
				.hasMessageContaining("status");
	}

	private static byte[] validBody() {
		return ("""
				{"providerEventId":"evt-100","providerPaymentId":"pay-100",\
				"orderId":"%s","status":"PAID","amount":49.00,"currency":"INR",\
				"occurredAt":"2026-08-15T07:00:00Z"}
				""").formatted(ORDER_ID).getBytes(StandardCharsets.UTF_8);
	}

	private static String sign(byte[] body) throws Exception {
		Mac mac = Mac.getInstance("HmacSHA256");
		mac.init(new SecretKeySpec(SECRET.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
		return HexFormat.of().formatHex(mac.doFinal(body));
	}
}
