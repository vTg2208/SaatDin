package com.saatdin.billing.coverage;

import java.time.LocalDate;
import java.util.List;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

public record CoverageBatchRequest(@NotEmpty List<String> workerPhones, @NotNull LocalDate at) {
}
