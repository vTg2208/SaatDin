package com.saatdin.billing.payment;

import java.util.Map;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/webhooks/v1/payments")
public class WebhookController {

	private final WebhookProcessingService service;

	public WebhookController(WebhookProcessingService service) {
		this.service = service;
	}

	@PostMapping(path = "/{provider}", consumes = MediaType.APPLICATION_JSON_VALUE)
	public Map<String, String> receive(
			@PathVariable String provider,
			@RequestHeader("X-Webhook-Signature") String signature,
			@RequestBody byte[] body) {
		return Map.of("result", service.process(provider, signature, body).name());
	}
}
