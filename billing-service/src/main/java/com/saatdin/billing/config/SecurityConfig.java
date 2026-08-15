package com.saatdin.billing.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
public class SecurityConfig {

	@Bean
	InternalApiKeyFilter internalApiKeyFilter(BillingProperties properties) {
		return new InternalApiKeyFilter(properties);
	}

	@Bean
	SecurityFilterChain billingSecurityFilterChain(
			HttpSecurity http, InternalApiKeyFilter internalApiKeyFilter) throws Exception {
		return http
				.csrf(csrf -> csrf.disable())
				.httpBasic(basic -> basic.disable())
				.formLogin(form -> form.disable())
				.logout(logout -> logout.disable())
				.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.authorizeHttpRequests(authorize -> authorize
						.requestMatchers("/actuator/health/**", "/actuator/info").permitAll()
						.requestMatchers("/webhooks/v1/payments/**").permitAll()
						.requestMatchers("/internal/**", "/sandbox/**").permitAll()
						.anyRequest().denyAll())
				.addFilterBefore(internalApiKeyFilter, UsernamePasswordAuthenticationFilter.class)
				.build();
	}
}
