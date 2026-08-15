package com.saatdin.billing.coverage;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.saatdin.billing.config.BillingProperties;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/internal/v1/coverage")
public class CoverageController {

	private final CoverageQueryService service;
	private final BillingProperties properties;

	public CoverageController(CoverageQueryService service, BillingProperties properties) {
		this.service = service;
		this.properties = properties;
	}

	@GetMapping("/{phone}")
	public CoverageView find(@PathVariable String phone, @RequestParam LocalDate at) {
		return service.findCoverage(phone, at);
	}

	@PostMapping("/batch")
	public Map<String, CoverageView> findBatch(@Valid @RequestBody CoverageBatchRequest request) {
		LinkedHashSet<String> uniquePhones = new LinkedHashSet<>(request.workerPhones());
		if (uniquePhones.size() > properties.coverageMaxBatchSize()) {
			throw new IllegalArgumentException("coverage batch exceeds configured maximum");
		}
		Map<String, CoverageView> result = new LinkedHashMap<>();
		for (String phone : uniquePhones) {
			result.put(phone, service.findCoverage(phone, request.at()));
		}
		return result;
	}
}
