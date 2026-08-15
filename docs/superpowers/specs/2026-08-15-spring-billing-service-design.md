# Spring Billing and Coverage Service Design

## Purpose

Add a Spring Boot service that becomes SaatDin's authoritative source for premium
payment orders, verified payment transactions, and weekly coverage periods. The
existing FastAPI application remains responsible for workers, plans, disruption
triggers, fraud scoring, claims, and payout orchestration.

The service is introduced incrementally. It does not rewrite existing FastAPI
features and does not allow the Flutter client to declare a payment successful.

## Success Criteria

- A worker can request a payment order through the authenticated FastAPI API.
- The premium amount, plan, and coverage week are calculated by FastAPI rather
  than accepted from the Flutter client.
- A payment-provider adapter creates the provider order.
- Only a verified, idempotently processed provider event can mark an order paid.
- Marking an order paid creates one coverage period and one outbox event in the
  same database transaction.
- Duplicate order requests and duplicate webhook events do not duplicate money
  records or coverage.
- FastAPI checks the Spring service before accepting a claim or settling a payout.
- A billing-service failure never grants coverage.
- Development supports an explicit sandbox provider; production rejects it.

## Architecture Decision

Use a strangler-style Spring Boot microservice rather than a full backend rewrite
or an event-broker-first design.

```text
Flutter
   |
FastAPI public facade
   |-- workers, pricing, triggers, fraud, claims, payouts
   |
Spring Boot billing service
   |-- payment orders, provider adapters, webhooks, coverage ledger
   |
Supabase/PostgreSQL
   |-- public schema: FastAPI-owned data
   |-- billing schema: Spring-owned data
```

The first implementation uses synchronous REST between FastAPI and Spring. A
transactional outbox records domain events without requiring Kafka or RabbitMQ.
A broker can be added later without changing payment transactions.

## Technology

- Java 17
- Spring Boot 4.1.0
- Maven Wrapper
- Spring MVC and Bean Validation
- Spring Data JPA
- Spring Security
- Flyway
- PostgreSQL
- Spring Boot Actuator
- JUnit, MockMvc, and Testcontainers

The service lives in `billing-service/` and is independently buildable and
deployable.

## Ownership Rules

- Spring exclusively writes tables in the `billing` schema.
- FastAPI exclusively writes its existing `public` schema tables.
- Spring stores the worker phone number as an external subject identifier and
  does not modify the FastAPI worker row.
- Flutter never calls Spring internal endpoints directly.
- Provider webhooks call Spring directly and are authenticated by the selected
  provider adapter.
- FastAPI calls Spring with an internal API key supplied through environment
  configuration.

The existing `public.premium_payments` table becomes a legacy development
fallback. Production configuration requires the Spring billing service and does
not use that table for coverage decisions.

## Data Model

All timestamps use UTC. Money uses `NUMERIC(12,2)`, never floating point.

### `billing.payment_orders`

- `id UUID` primary key
- `worker_phone VARCHAR(15)`
- `plan_code VARCHAR(40)`
- `amount NUMERIC(12,2)`
- `currency CHAR(3)` constrained to `INR`
- `coverage_week_start DATE`
- `provider VARCHAR(40)`
- `provider_order_id VARCHAR(160)` nullable and unique per provider
- `status VARCHAR(24)`
- `idempotency_key VARCHAR(120)` unique
- `expires_at TIMESTAMPTZ`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

### `billing.payment_transactions`

- `id UUID` primary key
- `payment_order_id UUID` foreign key
- `provider VARCHAR(40)`
- `provider_payment_id VARCHAR(160)` unique per provider
- `amount NUMERIC(12,2)`
- `currency CHAR(3)`
- `status VARCHAR(24)`
- `occurred_at TIMESTAMPTZ`
- `created_at TIMESTAMPTZ`

### `billing.coverage_periods`

- `id UUID` primary key
- `worker_phone VARCHAR(15)`
- `payment_order_id UUID` unique foreign key
- `plan_code VARCHAR(40)`
- `starts_on DATE`
- `ends_on DATE`
- `status VARCHAR(24)`
- `activated_at TIMESTAMPTZ`
- `revoked_at TIMESTAMPTZ` nullable
- partial unique index on worker and start date where status is `ACTIVE`

### `billing.webhook_receipts`

- `id UUID` primary key
- `provider VARCHAR(40)`
- `provider_event_id VARCHAR(160)`
- `payload_sha256 CHAR(64)`
- `processing_status VARCHAR(24)`
- `received_at TIMESTAMPTZ`
- `processed_at TIMESTAMPTZ` nullable
- unique constraint on provider and provider event ID

The raw webhook payload is not retained by default because it may contain
unnecessary personal data. The receipt stores only identifiers and a hash.

### `billing.outbox_events`

- `id UUID` primary key
- `aggregate_type VARCHAR(80)`
- `aggregate_id UUID`
- `event_type VARCHAR(120)`
- `payload JSONB`
- `created_at TIMESTAMPTZ`
- `published_at TIMESTAMPTZ` nullable

## Domain Rules

Payment order states are `CREATED`, `PENDING`, `PAID`, `FAILED`, `EXPIRED`, and
`REFUNDED`.

Allowed transitions:

```text
CREATED -> PENDING
CREATED -> FAILED
PENDING -> PAID
PENDING -> FAILED
PENDING -> EXPIRED
PAID -> REFUNDED
```

Repeated notification of the current state is idempotent. Any other transition
returns a conflict and does not modify records.

Coverage states are `ACTIVE` and `REVOKED`. A paid order activates Monday through
Sunday coverage for the order's `coverage_week_start`. Refund handling revokes
that order's coverage and emits `coverage.revoked`.

The initial order always targets the next Monday because the current SaatDin
product schedules newly purchased coverage for the next weekly cycle.

## Payment Provider Boundary

`PaymentProvider` is a Java interface with these operations:

- create a provider payment order
- verify and parse a webhook
- expose the provider name

The first adapter is `SandboxPaymentProvider`. It generates deterministic local
provider identifiers and accepts completion only through a development-profile
endpoint. The application fails startup when the sandbox provider is selected in
the production profile.

Provider-neutral domain services do not contain Razorpay, Stripe, or sandbox
conditionals. A real adapter can be added as a separate implementation.

## Spring API Contract

All JSON fields use camel case. Errors use RFC 7807 problem details.

### Internal endpoints

- `POST /internal/v1/payment-orders`
  - requires `X-Internal-Api-Key` and `Idempotency-Key`
  - accepts worker phone, plan code, authoritative amount, and week start
  - returns the order and provider checkout data
- `GET /internal/v1/payment-orders/{orderId}`
  - requires a `workerPhone` query parameter supplied by FastAPI
  - returns status only when that worker phone owns the order
- `GET /internal/v1/coverage/{phone}?at=YYYY-MM-DD`
  - returns `active`, `planCode`, `startsOn`, and `endsOn`; period fields are null
    when coverage is inactive
- `POST /internal/v1/coverage/batch`
  - accepts unique worker phones and a date, with a configured maximum batch size

### Provider endpoint

- `POST /webhooks/v1/payments/{provider}`
  - verifies the provider signature before processing
  - records the provider event ID idempotently
  - performs payment, transaction, coverage, and outbox writes transactionally

### Development-only endpoint

- `POST /sandbox/v1/payment-orders/{orderId}/complete`
  - available only under the `sandbox` Spring profile
  - converts a sandbox order into a verified provider event

## FastAPI Integration

Add a typed asynchronous billing client with short connection and request
timeouts. It sends the internal API key and propagates a correlation ID.

Public FastAPI behavior:

- `POST /api/v1/policy/payment-orders` authenticates the worker, resolves the
  current plan price, selects the next coverage week, and creates the Spring
  order. Client-supplied amounts and phone numbers are not accepted.
- `GET /api/v1/policy/payment-orders/{orderId}` returns the authenticated
  worker's order status.
- The old `POST /api/v1/policy/premium-payment` endpoint remains available only
  when the billing integration is disabled in development.
- `POST /api/v1/policy/payment-orders/{orderId}/sandbox-complete` proxies sandbox
  completion only when FastAPI is running outside production and Spring reports
  the sandbox provider.
- `has_active_coverage` queries Spring when billing integration is enabled.
- Timeouts, authentication errors, malformed responses, and Spring 5xx responses
  are treated as no confirmed coverage for claim and payout decisions.

Production configuration requires `BILLING_SERVICE_URL`, a non-default
`BILLING_SERVICE_API_KEY`, and billing integration enabled.

## Flutter Integration

The existing payment confirmation action calls the new FastAPI payment-order
endpoint. In the sandbox environment it then calls a FastAPI development proxy
that completes the sandbox order and polls the order until it is paid. Production
does not expose this completion proxy; a future real provider adapter will return
provider checkout details for the client SDK.

The success screen is shown only after FastAPI reports `PAID`. Network errors keep
the order pending and present a retry action rather than claiming coverage is
active.

## Security

- Internal endpoints use constant-time API-key comparison.
- The internal key and provider secrets come only from environment configuration.
- Logs never include API keys, webhook signatures, or complete webhook payloads.
- Webhook verification occurs before domain mutation.
- Order lookup always verifies worker ownership.
- Request validation limits phone, plan, provider, and idempotency-key lengths.
- Actuator exposes health and info only; other endpoints are disabled externally.
- Sandbox completion and provider selection are rejected in production.

## Reliability And Failure Handling

- Database uniqueness constraints provide the final idempotency guarantee.
- Order creation returns the existing order when the same idempotency key and
  request are repeated.
- Reusing an idempotency key with different request data returns HTTP 409.
- Duplicate webhook events return success without repeating state changes.
- Coverage activation and outbox creation share the payment transaction.
- FastAPI retries only safe GET requests. It does not blindly retry order creation
  without the same idempotency key.
- Coverage checks fail closed.

## Testing Strategy

Spring tests:

- unit tests for every allowed and rejected state transition
- service tests for idempotent order creation
- webhook tests for invalid signatures and duplicate events
- transaction tests proving one paid transaction creates one coverage period
- security tests for missing and incorrect internal keys
- controller tests for validation and RFC 7807 errors
- PostgreSQL integration tests using Testcontainers when Docker is available

FastAPI tests:

- order requests ignore client-controlled financial values
- billing client headers, timeouts, and response validation
- coverage checks fail closed on timeout and invalid responses
- local premium-table fallback works only in development mode
- production validation requires billing configuration

Flutter tests:

- payment success requires a paid order response
- pending and failed orders do not navigate to the success screen
- retry preserves the same order instead of creating another payment

End-to-end sandbox scenario:

1. Authenticate and register a worker.
2. Create a payment order through FastAPI.
3. Complete it through the sandbox path.
4. Confirm the order becomes paid.
5. Confirm the coverage API returns active for the purchased week.
6. Confirm a duplicate completion does not create duplicate coverage.

## Deployment And Operations

- The Spring service has its own container and CI job.
- Flyway owns all `billing` schema migrations.
- Health checks distinguish liveness from database readiness.
- Structured logs include correlation ID, order ID, and provider event ID.
- Metrics include created, paid, failed, expired, duplicate webhook, webhook
  verification failure, and coverage-check latency counts.
- The initial deployment uses the same Supabase/Postgres instance and a database
  role restricted to the `billing` schema.

## Delivery Scope

This implementation includes the Spring service, sandbox provider, schema,
internal APIs, FastAPI adapter and public facade, Flutter sandbox flow, automated
tests, environment templates, CI configuration, and documentation.

It does not include a live payment-provider adapter, a message broker, recurring
automatic debits, refunds initiated from an admin UI, or historical migration of
legacy premium rows. Those are separate production increments.
