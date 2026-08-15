package com.saatdin.billing.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import com.saatdin.billing.config.BillingProperties;
import com.saatdin.billing.config.InternalApiKeyFilter;

import jakarta.servlet.FilterChain;

class InternalApiSecurityTest {

	private final BillingProperties properties = new BillingProperties(
			"0123456789abcdef0123456789abcdef", "sandbox", "sandbox-secret", 100, "development");
	private final InternalApiKeyFilter filter = new InternalApiKeyFilter(properties);

	@Test
	void missingInternalKeyReturnsUnauthorized() throws Exception {
		MockHttpServletRequest request = new MockHttpServletRequest("GET", "/internal/v1/coverage/9876543210");
		MockHttpServletResponse response = new MockHttpServletResponse();
		FilterChain chain = Mockito.mock(FilterChain.class);

		filter.doFilter(request, response, chain);

		assertThat(response.getStatus()).isEqualTo(401);
		verify(chain, never()).doFilter(request, response);
	}

	@Test
	void correctInternalKeyReachesController() throws Exception {
		MockHttpServletRequest request = new MockHttpServletRequest("GET", "/internal/v1/coverage/9876543210");
		request.addHeader("X-Internal-Api-Key", properties.internalApiKey());
		MockHttpServletResponse response = new MockHttpServletResponse();
		FilterChain chain = Mockito.mock(FilterChain.class);

		filter.doFilter(request, response, chain);

		verify(chain).doFilter(request, response);
	}

	@Test
	void webhookDoesNotRequireInternalKey() throws Exception {
		MockHttpServletRequest request = new MockHttpServletRequest("POST", "/webhooks/v1/payments/sandbox");
		MockHttpServletResponse response = new MockHttpServletResponse();
		FilterChain chain = Mockito.mock(FilterChain.class);

		filter.doFilter(request, response, chain);

		verify(chain).doFilter(request, response);
	}

	@Test
	void sandboxCompletionRequiresInternalKey() throws Exception {
		MockHttpServletRequest request = new MockHttpServletRequest(
				"POST", "/sandbox/v1/payment-orders/63c40536-b23a-4d52-8360-1a08454dcd10/complete");
		MockHttpServletResponse response = new MockHttpServletResponse();
		FilterChain chain = Mockito.mock(FilterChain.class);

		filter.doFilter(request, response, chain);

		assertThat(response.getStatus()).isEqualTo(401);
		verify(chain, never()).doFilter(request, response);
	}
}
