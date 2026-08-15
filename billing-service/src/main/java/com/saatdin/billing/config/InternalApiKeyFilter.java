package com.saatdin.billing.config;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

public class InternalApiKeyFilter extends OncePerRequestFilter {

	public static final String HEADER = "X-Internal-Api-Key";

	private final byte[] expectedKey;

	public InternalApiKeyFilter(BillingProperties properties) {
		this.expectedKey = properties.internalApiKey().getBytes(StandardCharsets.UTF_8);
	}

	@Override
	protected boolean shouldNotFilter(HttpServletRequest request) {
		String path = request.getRequestURI();
		return !path.startsWith("/internal/") && !path.startsWith("/sandbox/");
	}

	@Override
	protected void doFilterInternal(
			HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
			throws ServletException, IOException {
		String supplied = request.getHeader(HEADER);
		byte[] suppliedBytes = supplied == null ? new byte[0] : supplied.getBytes(StandardCharsets.UTF_8);
		if (!MessageDigest.isEqual(expectedKey, suppliedBytes)) {
			response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
			response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
			response.getWriter().write("""
					{"type":"about:blank","title":"Unauthorized","status":401,"detail":"Invalid internal API key"}
					""");
			return;
		}
		filterChain.doFilter(request, response);
	}
}
