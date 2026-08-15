# Spring Billing and Coverage Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an independently deployable Spring Boot service that owns verified premium payments and weekly coverage, then integrate it behind the existing FastAPI facade and Flutter payment flow.

**Architecture:** Spring Boot owns the `billing` PostgreSQL schema and exposes authenticated internal REST APIs plus provider webhooks. FastAPI remains the public API, calculates authoritative premiums, and fails closed when Spring cannot confirm coverage; Flutter creates and tracks payment orders only through FastAPI.

**Tech Stack:** Java 17, Spring Boot 4.1.0, Maven Wrapper, Spring MVC, Spring Data JPA, Spring Security, Flyway, PostgreSQL, Testcontainers, Python 3.11/FastAPI/httpx, Flutter/Dart.

## Global Constraints

- Spring exclusively writes the `billing` schema; FastAPI exclusively writes its existing `public` schema.
- Flutter never sends authoritative phone, premium amount, plan price, or payment status values.
- Money is represented as Java `BigDecimal`, PostgreSQL `NUMERIC(12,2)`, Python `Decimal`, and integer paise where transport ambiguity would otherwise exist.
- All timestamps are UTC and coverage dates follow Monday-through-Sunday cycles.
- Internal APIs require `X-Internal-Api-Key`; mutating order creation also requires `Idempotency-Key`.
- Coverage checks fail closed on timeouts, authentication failures, malformed responses, and server errors.
- The sandbox payment adapter and completion endpoint cannot start under the production profile.
- Every production behavior is introduced through a failing test before implementation.
- Existing audit changes are preserved and committed separately before feature work.

---

## File Structure

### Spring service

- `billing-service/pom.xml`: dependency and build configuration.
- `billing-service/mvnw`, `billing-service/mvnw.cmd`, `billing-service/.mvn/wrapper/*`: reproducible Maven runtime.
- `billing-service/src/main/java/com/saatdin/billing/BillingServiceApplication.java`: application entry point.
- `billing-service/src/main/java/com/saatdin/billing/config/BillingProperties.java`: validated billing configuration.
- `billing-service/src/main/java/com/saatdin/billing/config/SecurityConfig.java`: internal-key and endpoint security.
- `billing-service/src/main/java/com/saatdin/billing/config/InternalApiKeyFilter.java`: constant-time internal API-key verification.
- `billing-service/src/main/java/com/saatdin/billing/order/*`: payment-order aggregate, repository, service, and controller.
- `billing-service/src/main/java/com/saatdin/billing/provider/*`: provider interface and normalized webhook types.
- `billing-service/src/main/java/com/saatdin/billing/provider/sandbox/*`: development-only sandbox adapter and controller.
- `billing-service/src/main/java/com/saatdin/billing/payment/*`: payment transaction and webhook processing.
- `billing-service/src/main/java/com/saatdin/billing/coverage/*`: coverage entity, query service, and controller.
- `billing-service/src/main/java/com/saatdin/billing/outbox/*`: transactional domain-event records.
- `billing-service/src/main/java/com/saatdin/billing/shared/*`: clock configuration and RFC 7807 exception mapping.
- `billing-service/src/main/resources/application.yml`: defaults and production fail-fast configuration.
- `billing-service/src/main/resources/db/migration/V1__create_billing_schema.sql`: owned PostgreSQL schema.
- `billing-service/src/test/java/com/saatdin/billing/**/*Test.java`: unit and MVC tests.
- `billing-service/src/test/java/com/saatdin/billing/**/*IT.java`: PostgreSQL Testcontainers tests.

### FastAPI integration

- `backend/app/services/billing_client.py`: typed async client and response validation.
- `backend/app/services/coverage.py`: Spring-backed authoritative coverage checks with development fallback.
- `backend/app/api/policy.py`: public payment-order facade and sandbox completion proxy.
- `backend/app/models/schemas.py`: public payment-order request/response models.
- `backend/app/core/config.py`: billing URL, key, timeout, and environment validation.
- `backend/app/main.py`: billing client lifecycle.
- `backend/tests/test_billing_client.py`: client contract and fail-closed tests.
- `backend/tests/test_policy_api.py`: authenticated order facade tests.
- `backend/tests/test_runtime_config.py`: production billing configuration tests.

### Flutter integration

- `lib/models/payment_order_model.dart`: payment-order state model.
- `lib/services/api_service.dart`: create, retrieve, and sandbox-complete calls.
- `lib/screens/onboarding/payment/payment_method_screen.dart`: order orchestration and retry behavior.
- `lib/screens/onboarding/payment/payment_success_screen.dart`: paid-order-only success contract.
- `test/models_test.dart`: payment-order parsing tests.
- `test/api_service_test.dart`: endpoint payload tests.
- `test/payout_flow_widget_test.dart`: pending, failure, retry, and success navigation tests.

### Operations

- `.github/workflows/flutter_ci.yml`: Java build job.
- `backend/.env.example`: FastAPI billing settings.
- `billing-service/.env.example`: service configuration contract.
- `README.md` and `setup guide.md`: local multi-service workflow and production boundary.

---

### Task 1: Preserve the Audited Baseline and Scaffold Spring Boot

**Files:**
- Commit existing modified audit files without altering their content.
- Create: `billing-service/pom.xml`
- Create: `billing-service/mvnw`
- Create: `billing-service/mvnw.cmd`
- Create: `billing-service/.mvn/wrapper/maven-wrapper.properties`
- Create: `billing-service/src/main/java/com/saatdin/billing/BillingServiceApplication.java`
- Create: `billing-service/src/main/resources/application.yml`
- Create: `billing-service/src/test/java/com/saatdin/billing/BillingServiceApplicationTest.java`

**Interfaces:**
- Produces: a Spring Boot 4.1.0 Java 17 service runnable with `./mvnw spring-boot:run` and testable with `./mvnw test`.

- [ ] **Step 1: Verify and commit the existing audit baseline**

Run:

```powershell
python -m pytest backend/tests -q
flutter analyze --no-pub
flutter test --no-pub
git diff --check
```

Expected: all Python and Flutter tests pass, analyzer reports no issues, and diff check exits zero. Stage only the existing audit paths and commit:

```powershell
git add .github .gitattributes .gitignore PROJECT_INFO.md README.md android backend ios lib scripts "setup guide.md" test web
git commit -m "fix: harden SaatDin production boundaries"
```

- [ ] **Step 2: Generate the Maven Wrapper project skeleton**

Generate a Maven/Java project with group `com.saatdin`, artifact
`billing-service`, package `com.saatdin.billing`, Java 17, Spring Boot 4.1.0, and
the required starters:

```powershell
$zip = Join-Path $env:TEMP 'saatdin-billing-service.zip'
Invoke-WebRequest 'https://start.spring.io/starter.zip?type=maven-project&language=java&bootVersion=4.1.0&baseDir=billing-service&groupId=com.saatdin&artifactId=billing-service&name=billing-service&packageName=com.saatdin.billing&packaging=jar&javaVersion=17&dependencies=web,data-jpa,validation,security,actuator,flyway,postgresql' -OutFile $zip
Expand-Archive $zip -DestinationPath . -Force
git update-index --add --chmod=+x billing-service/mvnw
```

Do not modify any path outside `billing-service/` in this step.

- [ ] **Step 3: Run the generated context test and verify the datasource failure**

Run: `billing-service\mvnw.cmd test`

Expected: FAIL because JPA cannot configure a datasource without billing database
settings. This is a generated-project/configuration test boundary rather than a
new production behavior.

- [ ] **Step 4: Isolate the context smoke test from the database**

```java
@SpringBootTest(properties = {
    "spring.autoconfigure.exclude=org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration,org.springframework.boot.hibernate.jpa.autoconfigure.HibernateJpaAutoConfiguration"
})
class BillingServiceApplicationTest {
    @Test
    void contextLoads() {
    }
}
```

- [ ] **Step 5: Add the minimal application configuration**

Use `@SpringBootApplication` with a standard `main` method. Configure port 8082,
disable Open Session in View, expose Actuator `health,info`, and map datasource
properties from `BILLING_DB_URL`, `BILLING_DB_USERNAME`, and
`BILLING_DB_PASSWORD`.

- [ ] **Step 6: Run the context test and commit**

Run: `billing-service\mvnw.cmd test`

Expected: PASS.

```powershell
git add billing-service
git commit -m "build: scaffold Spring billing service"
```

---

### Task 2: Define Payment Order and Coverage Domain Rules

**Files:**
- Create: `billing-service/src/main/java/com/saatdin/billing/order/PaymentOrderStatus.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/order/PaymentOrder.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/order/InvalidPaymentTransitionException.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/coverage/CoverageStatus.java`
- Test: `billing-service/src/test/java/com/saatdin/billing/order/PaymentOrderTest.java`

**Interfaces:**
- Produces: `PaymentOrder.markPending()`, `markPaid()`, `markFailed()`, `markExpired()`, and `markRefunded()`.
- Produces: immutable accessors for order identity, worker, plan, amount, week, provider, status, and timestamps.

- [ ] **Step 1: Write failing transition tests**

```java
@Test
void pendingOrderCanBecomePaid() {
    PaymentOrder order = PaymentOrder.create(command(), clock.instant());
    order.markPending(clock.instant(), "sandbox-order-1");
    order.markPaid(clock.instant());
    assertThat(order.status()).isEqualTo(PaymentOrderStatus.PAID);
}

@Test
void failedOrderCannotBecomePaid() {
    PaymentOrder order = PaymentOrder.create(command(), clock.instant());
    order.markFailed(clock.instant());
    assertThatThrownBy(() -> order.markPaid(clock.instant()))
        .isInstanceOf(InvalidPaymentTransitionException.class);
}

@Test
void repeatingCurrentStateIsIdempotent() {
    PaymentOrder order = PaymentOrder.create(command(), clock.instant());
    order.markPending(clock.instant(), "sandbox-order-1");
    order.markPending(clock.instant(), "sandbox-order-1");
    assertThat(order.status()).isEqualTo(PaymentOrderStatus.PENDING);
}
```

- [ ] **Step 2: Run tests and verify RED**

Run: `billing-service\mvnw.cmd -Dtest=PaymentOrderTest test`

Expected: compilation failure because the aggregate and statuses do not exist.

- [ ] **Step 3: Implement the minimal aggregate**

Implement the exact transition graph from the design. `PaymentOrder.create`
rejects non-positive amounts, non-Monday week starts, blank worker/plan/provider,
and currencies other than `INR`.

- [ ] **Step 4: Add edge-case tests and verify GREEN**

Add tests for invalid amount, Sunday week start, `PENDING -> EXPIRED`,
`PAID -> REFUNDED`, and rejected `CREATED -> PAID`.

Run: `billing-service\mvnw.cmd -Dtest=PaymentOrderTest test`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add billing-service/src/main/java/com/saatdin/billing/order billing-service/src/main/java/com/saatdin/billing/coverage billing-service/src/test/java/com/saatdin/billing/order
git commit -m "feat: define billing domain transitions"
```

---

### Task 3: Create the Billing Schema and Persistence Adapters

**Files:**
- Create: `billing-service/src/main/resources/db/migration/V1__create_billing_schema.sql`
- Create: repository interfaces under `order`, `payment`, `coverage`, and `outbox`.
- Create: JPA entities or JPA mappings colocated with their owning domain package.
- Test: `billing-service/src/test/java/com/saatdin/billing/persistence/BillingSchemaIT.java`

**Interfaces:**
- Produces: `PaymentOrderRepository`, `PaymentTransactionRepository`, `CoveragePeriodRepository`, `WebhookReceiptRepository`, and `OutboxEventRepository`.
- `PaymentOrderRepository.findByIdempotencyKey(String)` returns an optional order.
- `CoveragePeriodRepository.findActive(String workerPhone, LocalDate at)` returns the period containing `at`.

- [ ] **Step 1: Write the failing PostgreSQL integration test**

```java
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@ActiveProfiles("test")
class BillingSchemaIT {
    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:17-alpine");

    @Autowired JdbcTemplate jdbc;

    @Test
    void flywayCreatesAllOwnedTables() {
        Integer count = jdbc.queryForObject("""
            select count(*) from information_schema.tables
            where table_schema = 'billing'
              and table_name in ('payment_orders','payment_transactions',
                'coverage_periods','webhook_receipts','outbox_events')
            """, Integer.class);
        assertThat(count).isEqualTo(5);
    }
}
```

- [ ] **Step 2: Run and verify RED**

Run: `billing-service\mvnw.cmd -Dtest=BillingSchemaIT test`

Expected: FAIL because the Flyway migration and tables do not exist, or SKIP only when Docker is unavailable.

- [ ] **Step 3: Implement the migration and repositories**

Create all columns, checks, foreign keys, provider uniqueness constraints, the
partial unique active-coverage index, and indexes for worker/date and outbox
publication queries. Set Hibernate schema validation to `validate`; never use
Hibernate schema creation.

- [ ] **Step 4: Test persistence behavior**

Add integration tests proving duplicate idempotency keys, duplicate provider
events, and duplicate active worker/week coverage are rejected by PostgreSQL.

Run: `billing-service\mvnw.cmd test`

Expected: PASS, with Docker-dependent tests explicitly reported as skipped only
when Docker is unavailable.

- [ ] **Step 5: Commit**

```powershell
git add billing-service/src/main/resources/db billing-service/src/main/java/com/saatdin/billing billing-service/src/test/java/com/saatdin/billing/persistence
git commit -m "feat: add billing ledger persistence"
```

---

### Task 4: Implement the Provider Interface and Sandbox Adapter

**Files:**
- Create: `billing-service/src/main/java/com/saatdin/billing/provider/PaymentProvider.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/provider/ProviderOrder.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/provider/VerifiedPaymentEvent.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/provider/InvalidWebhookSignatureException.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/provider/sandbox/SandboxPaymentProvider.java`
- Test: `billing-service/src/test/java/com/saatdin/billing/provider/sandbox/SandboxPaymentProviderTest.java`

**Interfaces:**

```java
public interface PaymentProvider {
    String name();
    ProviderOrder createOrder(UUID orderId, BigDecimal amount, String currency);
    VerifiedPaymentEvent verifyWebhook(String signature, byte[] body);
}
```

- [ ] **Step 1: Write failing adapter tests**

Test that provider order IDs equal `sandbox_<order UUID>`, valid HMAC-SHA256
webhooks produce a normalized event, invalid signatures throw
`InvalidWebhookSignatureException`, and malformed payloads are rejected.

- [ ] **Step 2: Run and verify RED**

Run: `billing-service\mvnw.cmd -Dtest=SandboxPaymentProviderTest test`

Expected: compilation failure because the interface and adapter do not exist.

- [ ] **Step 3: Implement the minimal provider boundary**

Use Jackson for the sandbox payload and `MessageDigest.isEqual` for signature
comparison. The normalized event contains provider event ID, provider payment ID,
order ID, status, amount, currency, and occurrence time.

- [ ] **Step 4: Verify GREEN and commit**

Run: `billing-service\mvnw.cmd -Dtest=SandboxPaymentProviderTest test`

Expected: PASS.

```powershell
git add billing-service/src/main/java/com/saatdin/billing/provider billing-service/src/test/java/com/saatdin/billing/provider
git commit -m "feat: add sandbox payment provider"
```

---

### Task 5: Implement Idempotent Payment Order Creation

**Files:**
- Create: `billing-service/src/main/java/com/saatdin/billing/order/CreatePaymentOrderCommand.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/order/PaymentOrderService.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/order/PaymentOrderQueryService.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/order/IdempotencyConflictException.java`
- Test: `billing-service/src/test/java/com/saatdin/billing/order/PaymentOrderServiceTest.java`

**Interfaces:**
- Produces: `PaymentOrder create(CreatePaymentOrderCommand command, String idempotencyKey)`.
- Produces: `PaymentOrder getOwned(UUID orderId, String workerPhone)` that expires
  overdue pending orders before returning them.
- Consumes: `PaymentOrderRepository`, `PaymentProvider`, and injected `Clock`.

- [ ] **Step 1: Write failing service tests**

```java
@Test
void repeatedIdenticalRequestReturnsExistingOrder() {
    PaymentOrder first = service.create(command, "checkout-123");
    PaymentOrder second = service.create(command, "checkout-123");
    assertThat(second.id()).isEqualTo(first.id());
    verify(provider, times(1)).createOrder(any(), any(), eq("INR"));
}

@Test
void changedRequestWithSameKeyIsRejected() {
    service.create(command, "checkout-123");
    assertThatThrownBy(() -> service.create(command.withAmount(new BigDecimal("99.00")), "checkout-123"))
        .isInstanceOf(IdempotencyConflictException.class);
}
```

- [ ] **Step 2: Run and verify RED**

Run: `billing-service\mvnw.cmd -Dtest=PaymentOrderServiceTest test`

Expected: compilation failure because the service does not exist.

- [ ] **Step 3: Implement order creation transaction**

Normalize phone and plan, compare every financial request field on idempotent
replay, create the local order, call the provider, mark it pending, and persist.
Map database unique-key races back to the stored order or HTTP 409 as appropriate.

Implement owned-order retrieval that compares the normalized worker phone and
marks a `PENDING` order `EXPIRED` when `expiresAt` is not after the injected
clock. Add tests proving another worker cannot read the order and an overdue
order is persisted as expired on retrieval.

- [ ] **Step 4: Verify GREEN and commit**

Run: `billing-service\mvnw.cmd -Dtest=PaymentOrderServiceTest test`

Expected: PASS.

```powershell
git add billing-service/src/main/java/com/saatdin/billing/order billing-service/src/test/java/com/saatdin/billing/order
git commit -m "feat: create idempotent payment orders"
```

---

### Task 6: Process Verified Webhooks and Activate Coverage Transactionally

**Files:**
- Create: `billing-service/src/main/java/com/saatdin/billing/payment/PaymentTransaction.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/payment/WebhookReceipt.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/payment/WebhookProcessingService.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/payment/BillingMetrics.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/coverage/CoveragePeriod.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/outbox/OutboxEvent.java`
- Test: `billing-service/src/test/java/com/saatdin/billing/payment/WebhookProcessingServiceTest.java`
- Test: `billing-service/src/test/java/com/saatdin/billing/payment/WebhookTransactionIT.java`

**Interfaces:**
- Produces: `WebhookResult process(String provider, String signature, byte[] body)`.
- Produces: `CoverageView findCoverage(String phone, LocalDate at)`.

- [ ] **Step 1: Write failing paid-event tests**

Test that one verified `PAID` event marks the order paid and persists exactly one
transaction, active coverage period, webhook receipt, and
`coverage.activated` outbox event. Test duplicate provider event ID returns
`WebhookResult.DUPLICATE` without new writes.

- [ ] **Step 2: Run and verify RED**

Run: `billing-service\mvnw.cmd -Dtest=WebhookProcessingServiceTest test`

Expected: compilation failure because webhook processing does not exist.

- [ ] **Step 3: Implement transactional processing**

Resolve the provider by path name, verify the signature before repository access,
lock the payment order row, validate amount/currency/order identity, record the
receipt and transaction, transition the order, activate or revoke coverage, and
append an outbox event under one `@Transactional` method.

Store the lowercase SHA-256 hash of the webhook bytes in the receipt without
persisting or logging the raw body. Increment Micrometer counters named
`billing.orders.created`, `billing.payments.paid`, `billing.payments.failed`,
`billing.webhooks.duplicate`, and `billing.webhooks.signature-failed`; time
coverage queries with `billing.coverage.query`.

- [ ] **Step 4: Add rollback and refund tests**

Test amount mismatch, unknown order, illegal transition, simulated coverage
repository failure, `FAILED`, and `REFUNDED`. The rollback integration test must
show no partial transaction, receipt, coverage, or outbox writes.
Add a metrics test using `SimpleMeterRegistry` that asserts each result increments
only its corresponding counter and no metric tag contains a phone or order ID.

- [ ] **Step 5: Verify GREEN and commit**

Run: `billing-service\mvnw.cmd test`

Expected: PASS; Docker integration tests may skip only when Docker is absent.

```powershell
git add billing-service/src/main/java/com/saatdin/billing/payment billing-service/src/main/java/com/saatdin/billing/coverage billing-service/src/main/java/com/saatdin/billing/outbox billing-service/src/test/java/com/saatdin/billing/payment
git commit -m "feat: activate coverage from verified payments"
```

---

### Task 7: Secure and Expose Spring REST APIs

**Files:**
- Create: `billing-service/src/main/java/com/saatdin/billing/config/BillingProperties.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/config/InternalApiKeyFilter.java`
- Create: `billing-service/src/main/java/com/saatdin/billing/config/SecurityConfig.java`
- Create controllers and DTOs under `order`, `payment`, `coverage`, and `provider/sandbox`.
- Create: `billing-service/src/main/java/com/saatdin/billing/shared/ApiExceptionHandler.java`
- Test: `billing-service/src/test/java/com/saatdin/billing/api/InternalApiSecurityTest.java`
- Test: `billing-service/src/test/java/com/saatdin/billing/api/PaymentOrderControllerTest.java`
- Test: `billing-service/src/test/java/com/saatdin/billing/api/WebhookControllerTest.java`

**Interfaces:**
- Implements the exact endpoints and JSON fields from the approved design.
- Returns Spring `ProblemDetail` with stable `type`, `title`, `status`, and `detail` fields.

- [ ] **Step 1: Write failing MVC security tests**

Test internal endpoints return 401 without a key, 401 with a wrong key, and reach
the controller with the configured key. Test webhook and Actuator health paths do
not require the internal key. Test all other paths are denied.

- [ ] **Step 2: Run and verify RED**

Run: `billing-service\mvnw.cmd -Dtest=InternalApiSecurityTest test`

Expected: FAIL because endpoint security does not exist.

- [ ] **Step 3: Implement security and controllers**

Use a `OncePerRequestFilter`, UTF-8 byte arrays, and `MessageDigest.isEqual` for
constant-time key comparison. Validate order request amount precision, Monday
week, phone length, plan length, and idempotency key. Cap batch coverage queries
at `billing.coverage.max-batch-size`.

- [ ] **Step 4: Implement sandbox and production guards**

Register `SandboxPaymentProvider` and its completion controller only under the
`sandbox` profile. Add startup validation that rejects `sandbox` provider or
sandbox profile when `APP_ENVIRONMENT=production`.

- [ ] **Step 5: Verify all API tests and commit**

Run: `billing-service\mvnw.cmd test`

Expected: PASS.

```powershell
git add billing-service/src
git commit -m "feat: expose secured billing APIs"
```

---

### Task 8: Add the FastAPI Billing Client and Authoritative Coverage Adapter

**Files:**
- Create: `backend/app/services/billing_client.py`
- Modify: `backend/app/services/coverage.py`
- Modify: `backend/app/core/config.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_billing_client.py`
- Modify: `backend/tests/test_runtime_config.py`

**Interfaces:**

```python
class BillingClient:
    async def create_payment_order(self, request: PaymentOrderCreate) -> PaymentOrderView: ...
    async def get_payment_order(self, order_id: str, worker_phone: str) -> PaymentOrderView: ...
    async def complete_sandbox_order(self, order_id: str, worker_phone: str) -> PaymentOrderView: ...
    async def has_active_coverage(self, phone: str, at: date) -> bool: ...
```

- [ ] **Step 1: Write failing billing-client tests**

Use `httpx.MockTransport` to assert internal headers, JSON serialization,
correlation ID propagation, timeout configuration, strict response parsing, and
idempotency-key reuse. Test coverage returns false for timeout, 401, 5xx, and
malformed response.

- [ ] **Step 2: Run and verify RED**

Run: `python -m pytest backend/tests/test_billing_client.py -q`

Expected: import failure because `billing_client` does not exist.

- [ ] **Step 3: Implement the typed async client**

Use one lifecycle-managed `httpx.AsyncClient`; never create a client per request.
Define frozen dataclasses for `PaymentOrderCreate` and `PaymentOrderView`. Validate
UUID, decimal strings, dates, provider, and status before returning data.

- [ ] **Step 4: Route coverage through Spring with development fallback**

When `billing_service_enabled` is true, `coverage.has_active_coverage` delegates
to Spring and returns false on any unconfirmed result. When false, it uses the
existing local premium table only outside production.

- [ ] **Step 5: Add production validation**

Require `BILLING_SERVICE_ENABLED=true`, an HTTPS service URL except for explicitly
allowed private deployment URLs, and an API key of at least 32 characters. Reject
the local premium fallback in production.

- [ ] **Step 6: Verify and commit**

Run: `python -m pytest backend/tests/test_billing_client.py backend/tests/test_runtime_config.py backend/tests/test_claims_api.py backend/tests/test_payout_service.py backend/tests/test_triggers_api.py -q`

Expected: PASS.

```powershell
git add backend/app/services/billing_client.py backend/app/services/coverage.py backend/app/core/config.py backend/app/main.py backend/tests
git commit -m "feat: integrate authoritative billing coverage"
```

---

### Task 9: Add FastAPI Payment-Order Facade Endpoints

**Files:**
- Modify: `backend/app/models/schemas.py`
- Modify: `backend/app/api/policy.py`
- Modify: `backend/tests/test_policy_api.py`

**Interfaces:**
- Produces public `POST /api/v1/policy/payment-orders` without financial request fields.
- Produces public `GET /api/v1/policy/payment-orders/{order_id}`.
- Produces development-only `POST /api/v1/policy/payment-orders/{order_id}/sandbox-complete`.

- [ ] **Step 1: Write failing authenticated route tests**

Test that order creation derives phone from `get_current_worker`, calculates the
selected plan premium server-side, uses next Monday, and generates an idempotency
key from an optional safe client request ID plus authenticated worker identity.
Test order retrieval and sandbox completion enforce ownership.

- [ ] **Step 2: Run and verify RED**

Run: `python -m pytest backend/tests/test_policy_api.py -q`

Expected: 404 for the new endpoints.

- [ ] **Step 3: Implement minimal public schemas and routes**

The create request contains only `clientRequestId` with a maximum length of 80.
Return order ID, status, provider, amount, currency, week start, expiration, and
provider checkout data. Reject sandbox completion in production before calling
Spring.

- [ ] **Step 4: Retire client-reported payments when billing is enabled**

Update the existing premium-payment route to return HTTP 410 when billing is
enabled. Retain its development fallback only when the integration is disabled.

- [ ] **Step 5: Verify and commit**

Run: `python -m pytest backend/tests/test_policy_api.py backend/tests/test_claims_api.py backend/tests/test_payout_service.py -q`

Expected: PASS.

```powershell
git add backend/app/api/policy.py backend/app/models/schemas.py backend/tests/test_policy_api.py
git commit -m "feat: expose payment order facade"
```

---

### Task 10: Replace Flutter Self-Reported Payments with Order Tracking

**Files:**
- Create: `lib/models/payment_order_model.dart`
- Modify: `lib/services/api_service.dart`
- Modify: `lib/screens/onboarding/payment/payment_method_screen.dart`
- Modify: `lib/screens/onboarding/payment/payment_success_screen.dart`
- Modify: `test/models_test.dart`
- Modify: `test/api_service_test.dart`
- Modify: `test/payout_flow_widget_test.dart`

**Interfaces:**

```dart
Future<PaymentOrder> createPaymentOrder({required String clientRequestId});
Future<PaymentOrder> getPaymentOrder(String orderId);
Future<PaymentOrder> completeSandboxPaymentOrder(String orderId);
```

- [ ] **Step 1: Write failing model tests**

Test parsing `orderId`, `status`, decimal amount, `INR`, provider, week start,
expiration, and checkout data. Test `isPaid`, `isPending`, and malformed status.

- [ ] **Step 2: Run and verify RED**

Run: `flutter test --no-pub test/models_test.dart`

Expected: compilation failure because `PaymentOrder` does not exist.

- [ ] **Step 3: Implement the model and API methods**

Generate `clientRequestId` once when the payment screen state is created and keep
it across retries. Remove the call that submits `amount` and `status=paid`.

- [ ] **Step 4: Write failing widget tests**

Test pending orders remain on the payment screen, failures show retry without a
new client request ID, and only a `PAID` response navigates to
`PaymentSuccessScreen`.

- [ ] **Step 5: Run and verify RED**

Run: `flutter test --no-pub test/payout_flow_widget_test.dart`

Expected: FAIL because the current screen navigates after self-reporting payment.

- [ ] **Step 6: Implement order orchestration**

In sandbox development, create the order, request sandbox completion, then poll
the existing order with bounded attempts. Keep the action disabled during a
request, expose a retry for pending/network failure, and never display active
coverage before `isPaid`.

- [ ] **Step 7: Verify and commit**

Run:

```powershell
dart format lib/models/payment_order_model.dart lib/services/api_service.dart lib/screens/onboarding/payment/payment_method_screen.dart lib/screens/onboarding/payment/payment_success_screen.dart test/models_test.dart test/api_service_test.dart test/payout_flow_widget_test.dart
flutter analyze --no-pub
flutter test --no-pub
```

Expected: analyzer clean and all tests pass.

```powershell
git add lib test
git commit -m "feat: track verified premium payments"
```

---

### Task 11: Add Configuration, CI, Documentation, and End-to-End Verification

**Files:**
- Create: `billing-service/.env.example`
- Modify: `backend/.env.example`
- Modify: `.github/workflows/flutter_ci.yml`
- Modify: `README.md`
- Modify: `setup guide.md`
- Create: `billing-service/src/test/java/com/saatdin/billing/e2e/SandboxPaymentFlowIT.java`

**Interfaces:**
- Produces documented local ports: FastAPI 8000, Spring billing 8082, Flutter-selected client target.
- Produces a CI Java job that runs `billing-service/mvnw test`.

- [ ] **Step 1: Write the failing sandbox flow integration test**

The test creates an internal order, completes a correctly signed sandbox event,
queries the order, queries coverage for the purchased week, repeats completion,
and asserts one transaction and one active coverage period.

- [ ] **Step 2: Run and verify RED**

Run: `billing-service\mvnw.cmd -Dtest=SandboxPaymentFlowIT test`

Expected: FAIL until the complete controller-to-database flow is wired.

- [ ] **Step 3: Complete configuration and CI**

Document `BILLING_DB_*`, `BILLING_INTERNAL_API_KEY`,
`BILLING_SANDBOX_WEBHOOK_SECRET`, `BILLING_PROVIDER`, and
`APP_ENVIRONMENT`. Add a Java CI job using `actions/setup-java` with distribution
Temurin and Java 17, then run `./billing-service/mvnw -f billing-service/pom.xml test`.

- [ ] **Step 4: Update operational documentation**

Document startup order, schema ownership, sandbox-only status, health endpoints,
service URLs, failure behavior, and the exact commands for backend, billing, and
Flutter. Remove the old client-reported premium-payment instructions.

- [ ] **Step 5: Run the complete verification matrix**

```powershell
billing-service\mvnw.cmd test
python -m compileall -q backend/app backend/tests
python -m pytest backend/tests -q
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub
python -m pip install --dry-run --ignore-installed -r backend/requirements.txt
git diff --check
```

Run `flutter build apk --debug --no-pub` when Gradle dependency access is
available. If it remains blocked externally, capture that separately without
representing it as a code failure.

- [ ] **Step 6: Verify runtime guards**

Start Spring under the sandbox profile and confirm `/actuator/health` returns
200. Attempt production startup with the sandbox provider and confirm startup
fails. Start FastAPI without billing production settings and confirm startup
fails before database initialization.

- [ ] **Step 7: Commit**

```powershell
git add billing-service/.env.example backend/.env.example .github/workflows/flutter_ci.yml README.md "setup guide.md" billing-service/src/test/java/com/saatdin/billing/e2e
git commit -m "docs: complete billing service operations"
```

---

## Final Review Checklist

- [ ] Every Spring domain method was introduced after its test failed for the expected reason.
- [ ] Every FastAPI behavior was introduced after its test failed for the expected reason.
- [ ] Flutter does not submit payment amount, worker phone, or paid status.
- [ ] Duplicate order and webhook paths are covered at service and database levels.
- [ ] Coverage and outbox writes roll back with payment-processing failures.
- [ ] Production rejects sandbox payment and local premium-table fallback.
- [ ] FastAPI coverage decisions fail closed.
- [ ] No service writes another service's schema.
- [ ] Secrets and webhook bodies do not appear in logs or committed files.
- [ ] Full Java, Python, and Flutter verification outputs are recorded before completion.
