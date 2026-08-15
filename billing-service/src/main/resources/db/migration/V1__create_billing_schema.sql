CREATE SCHEMA IF NOT EXISTS billing;

CREATE TABLE billing.payment_orders (
    id UUID PRIMARY KEY,
    worker_phone VARCHAR(15) NOT NULL,
    plan_code VARCHAR(40) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) NOT NULL CHECK (currency = 'INR'),
    coverage_week_start DATE NOT NULL CHECK (EXTRACT(ISODOW FROM coverage_week_start) = 1),
    provider VARCHAR(40) NOT NULL,
    provider_order_id VARCHAR(160),
    status VARCHAR(24) NOT NULL CHECK (
        status IN ('CREATED', 'PENDING', 'PAID', 'FAILED', 'EXPIRED', 'REFUNDED')
    ),
    idempotency_key VARCHAR(120) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CHECK (expires_at > created_at)
);

CREATE UNIQUE INDEX uq_payment_orders_provider_order
    ON billing.payment_orders (provider, provider_order_id)
    WHERE provider_order_id IS NOT NULL;
CREATE INDEX ix_payment_orders_worker_created
    ON billing.payment_orders (worker_phone, created_at DESC);
CREATE INDEX ix_payment_orders_status_expires
    ON billing.payment_orders (status, expires_at);

CREATE TABLE billing.payment_transactions (
    id UUID PRIMARY KEY,
    payment_order_id UUID NOT NULL REFERENCES billing.payment_orders(id),
    provider VARCHAR(40) NOT NULL,
    provider_payment_id VARCHAR(160) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) NOT NULL CHECK (currency = 'INR'),
    status VARCHAR(24) NOT NULL CHECK (status IN ('CAPTURED', 'REFUNDED')),
    occurred_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    UNIQUE (provider, provider_payment_id)
);

CREATE INDEX ix_payment_transactions_order
    ON billing.payment_transactions (payment_order_id);

CREATE TABLE billing.coverage_periods (
    id UUID PRIMARY KEY,
    worker_phone VARCHAR(15) NOT NULL,
    payment_order_id UUID NOT NULL UNIQUE REFERENCES billing.payment_orders(id),
    plan_code VARCHAR(40) NOT NULL,
    starts_on DATE NOT NULL CHECK (EXTRACT(ISODOW FROM starts_on) = 1),
    ends_on DATE NOT NULL,
    status VARCHAR(24) NOT NULL CHECK (status IN ('ACTIVE', 'REVOKED')),
    activated_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    CHECK (ends_on = starts_on + 6),
    CHECK ((status = 'ACTIVE' AND revoked_at IS NULL) OR status = 'REVOKED')
);

CREATE UNIQUE INDEX uq_coverage_periods_active_week
    ON billing.coverage_periods (worker_phone, starts_on)
    WHERE status = 'ACTIVE';
CREATE INDEX ix_coverage_periods_worker_dates
    ON billing.coverage_periods (worker_phone, starts_on, ends_on);

CREATE TABLE billing.webhook_receipts (
    id UUID PRIMARY KEY,
    provider VARCHAR(40) NOT NULL,
    provider_event_id VARCHAR(160) NOT NULL,
    payload_sha256 VARCHAR(64) NOT NULL,
    status VARCHAR(24) NOT NULL CHECK (status IN ('RECEIVED', 'PROCESSED', 'REJECTED')),
    received_at TIMESTAMPTZ NOT NULL,
    processed_at TIMESTAMPTZ,
    UNIQUE (provider, provider_event_id)
);

CREATE TABLE billing.outbox_events (
    id UUID PRIMARY KEY,
    aggregate_type VARCHAR(80) NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    published_at TIMESTAMPTZ
);

CREATE INDEX ix_outbox_events_unpublished
    ON billing.outbox_events (created_at)
    WHERE published_at IS NULL;
