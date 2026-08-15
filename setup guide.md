# SaatDin Setup Guide

This guide runs the Flutter app, FastAPI application API, and Spring Boot billing service locally. FastAPI owns user, policy, claim, and payout workflows. Spring owns payment orders, verified transactions, and coverage periods; FastAPI is the only public facade used by Flutter.

## 1. Prerequisites

Install the following tools:
- Flutter SDK (stable)
- Dart SDK (comes with Flutter)
- Python 3.11+
- Java 17+
- Android Studio or VS Code + Android SDK
- Git
- PostgreSQL 14+ (a single database is sufficient)

Verify installation:

```powershell
flutter --version
dart --version
python --version
java --version
```

## 2. Project Structure (Important Paths)

- Flutter app source: lib/
- Flutter assets: assets/
- Zone risk data: assets/data/zone_risk_runtime.json
- Backend source: backend/app/main.py
- Backend dependencies: backend/requirements.txt
- Billing service: billing-service/
- Billing migrations: billing-service/src/main/resources/db/migration/
- Project story: PROJECT_INFO.md

## 3. Flutter App Setup

From project root, install dependencies:

```powershell
flutter pub get
```

Run the app:

```powershell
flutter run
```

## 4. Database and Billing Service

Both services may use the same PostgreSQL database, but ownership is separate. FastAPI uses the existing application tables. Spring Flyway exclusively owns the `billing` schema and creates it on startup. Do not let either service migrate the other service's tables.

Prepare environment values from `billing-service/.env.example`. PowerShell does not automatically load `.env` files, so export the values in the shell or configure them in your IDE:

```powershell
$env:APP_ENVIRONMENT='development'
$env:SPRING_PROFILES_ACTIVE='sandbox'
$env:BILLING_DB_URL='jdbc:postgresql://localhost:5432/postgres'
$env:BILLING_DB_USERNAME='postgres'
$env:BILLING_DB_PASSWORD='<password>'
$env:BILLING_INTERNAL_API_KEY='<same-32-character-key-used-by-fastapi>'
$env:BILLING_PROVIDER='sandbox'
$env:BILLING_SANDBOX_WEBHOOK_SECRET='<random-development-secret>'
```

Start Spring from the repository root:

```powershell
cd billing-service
.\mvnw.cmd spring-boot:run
cd ..
```

Verify it at `http://127.0.0.1:8082/actuator/health`.

The sandbox profile exposes a development-only completion route. Production startup rejects the sandbox profile/provider, and this repository intentionally has no live payment adapter yet.

## 5. Application API Setup (FastAPI)

From project root, install backend dependencies:

```powershell
python -m pip install -r backend/requirements.txt
```

Create environment config for the current Supabase/Postgres-backed backend:

```powershell
copy backend/.env.example backend/.env
```

Edit `backend/.env`; the database URL is required:

```env
SUPABASE_DB_URL=postgresql://postgres:<password>@<host>:5432/postgres
BILLING_SERVICE_ENABLED=true
BILLING_SERVICE_URL=http://127.0.0.1:8082
BILLING_SERVICE_API_KEY=<same-32-character-key-used-by-spring>
BILLING_REQUEST_TIMEOUT_SECONDS=2
BILLING_ALLOW_PRIVATE_HTTP=false
ALLOW_CLIENT_REPORTED_PREMIUM_PAYMENTS=false
FRAUD_SCORING_ENABLED=true
FRAUD_MODEL_PATH=backend/models/fraud/fraud_iforest_latest.joblib
FRAUD_ANOMALY_THRESHOLD=-0.05
FRAUD_FAIL_OPEN=true
```

The backend creates and verifies its application tables during startup. A blank `SUPABASE_DB_URL` is rejected. Coverage checks fail closed when Spring is unavailable; claims and payouts never infer coverage from a client-reported payment.

Optional: migrate legacy local SQLite data into Supabase once you need a hosted database:

```powershell
python backend/scripts/migrate_sqlite_to_supabase.py --sqlite backend/backend_data.db --supabase-db-url "postgresql://postgres:<password>@<host>:5432/postgres"
```

Train/version fraud anomaly model artifact:

```powershell
python backend/scripts/train_isolation_forest.py --output-dir backend/models/fraud --version v1
```

Start backend server:

```powershell
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
```

Backend base URL expected by app:
- Web, Windows, and iOS simulator: `http://localhost:8000/api/v1`
- Android emulator: `http://10.0.2.2:8000/api/v1`
- Physical device: `http://<development-machine-LAN-IP>:8000/api/v1`

## 6. Verify Services Are Running

Health check:

```powershell
curl http://127.0.0.1:8000/api/v1/health
curl http://127.0.0.1:8082/actuator/health
```

Expected response:

```json
{"status":"ok"}
```

## 7. Current Implemented API Endpoints

- GET /api/v1/health
- POST /api/v1/auth/send-otp
- POST /api/v1/auth/verify-otp
- GET /api/v1/platforms
- GET /api/v1/zones
- GET /api/v1/zones/{pincode}
- GET /api/v1/plans?zone={zone}&platform={platform}
- POST /api/v1/register
- GET /api/v1/workers/status
- GET /api/v1/workers/me
- PUT /api/v1/workers/me
- POST /api/v1/workers/location-signal
- GET /api/v1/policy
- PUT /api/v1/policy/update
- POST /api/v1/policy/payment-orders
- GET /api/v1/policy/payment-orders/{order_id}
- POST /api/v1/policy/payment-orders/{order_id}/sandbox-complete (development only)
- GET /api/v1/claims
- POST /api/v1/claims/submit
- POST /api/v1/claims/{claim_id}/escalate
- GET /api/v1/payouts/me
- PUT /api/v1/payouts/accounts/{slot}
- POST /api/v1/payouts/accounts/{slot}/verify
- GET /api/v1/payouts/statements
- GET /api/v1/triggers/active?zone={zone}
- POST /api/v1/triggers/zonelock/report
- GET /admin/dashboard

## 8. Run the Full Stack

Start order is PostgreSQL, Spring billing, FastAPI, then Flutter.

1. Terminal A (billing):

```powershell
cd billing-service
.\mvnw.cmd spring-boot:run
```

2. Terminal B (FastAPI):

```powershell
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
```

3. Terminal C (Flutter):

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

The example command targets an Android emulator. Admin review is available at `http://127.0.0.1:8000/admin/dashboard` with development credentials `admin` / `saatdin-local`.

Optional one-command Windows helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start-local.ps1
```

The Flutter client creates an idempotent order through FastAPI and only displays success after Spring verifies the payment and reports `PAID`. The removed `/policy/premium-payment` client-write flow is not part of normal operation.

## 9. Troubleshooting

### Android SDK location error
If you see SDK location not found, set Android SDK path in android/local.properties:

```properties
sdk.dir=C:\\Users\\<your-username>\\AppData\\Local\\Android\\Sdk
```

Or set ANDROID_HOME environment variable.

### Backend import/runtime errors
Reinstall backend dependencies:

```powershell
python -m pip install -r backend/requirements.txt --upgrade
```

### App cannot reach backend
- Ensure backend is running on 127.0.0.1:8000
- Pass the correct URL with `--dart-define=API_BASE_URL=...`
- Use `10.0.2.2` for an Android emulator; use the development machine's LAN IP for a physical device

### Coverage or checkout is unavailable
- Check Spring health on port 8082 before FastAPI.
- Confirm `BILLING_SERVICE_API_KEY` exactly matches `BILLING_INTERNAL_API_KEY`.
- Confirm the PostgreSQL user can create and use the `billing` schema.
- Expected behavior is fail-closed: an unreachable billing service does not grant coverage.

### Android release signing

Create an upload keystore, copy `android/key.properties.example` to
`android/key.properties`, and replace every placeholder. The real properties file
and keystore must stay out of version control. Release builds are not signed when
that file is absent.

## 10. Useful Dev Commands

```powershell
flutter analyze
flutter test
python -m compileall backend/app/main.py
cd billing-service; .\mvnw.cmd test; cd ..
python backend/scripts/train_isolation_forest.py --output-dir backend/models/fraud --version v1
```

## 11. Notes

- Zone and risk data are currently loaded from assets/data/zone_risk_runtime.json.
- Dynamic onboarding, claims, escalations, payouts, admin review, and mobile signal ingestion are integrated.
- The live backend is Supabase/Postgres-backed; SQLite migration remains a legacy path only.
- S3-compatible archival and BigQuery mirroring are planned; no archival job is implemented yet.
- OTP delivery, premium collection, UPI verification, and payouts are development simulations. Billing accepts payment state changes only from signed provider webhooks; the sandbox generates those signatures locally. Production mode intentionally refuses unsafe defaults, and live provider adapters must be implemented before launch.

## 12. Co-Claim Cluster Risk Scoring (Ops)

SaatDin includes a scheduled co-claim graph pipeline for coordinated-timing fraud analysis.

- **Pipeline cadence:** configurable via `CO_CLAIM_GRAPH_SCHEDULE_HOURS` (default 24).
- **Lookback window:** `CO_CLAIM_GRAPH_LOOKBACK_DAYS` (default 30).
- **Co-claim event bucket:** claims in the same zone + trigger type + `CO_CLAIM_GRAPH_TIME_BUCKET_MINUTES` are linked.
- **Edge support gate:** only user pairs with at least `CO_CLAIM_GRAPH_MIN_EDGE_SUPPORT` co-claim events are kept.

### Edge and cluster scoring

1. **Edge frequency score** = `min(1.0, co_claim_count / (2 * min_edge_support))`
2. **Edge recency score** = exponential half-life decay using `CO_CLAIM_GRAPH_RECENCY_HALF_LIFE_DAYS`
3. **Edge weight** = `0.65 * frequency + 0.35 * recency`
4. **Cluster risk score** = `0.45 * frequency + 0.25 * recency + 0.20 * density + 0.10 * activity`

Risk levels:
- **high**: `score >= CO_CLAIM_GRAPH_HIGH_RISK_THRESHOLD`
- **medium**: `score >= CO_CLAIM_GRAPH_MEDIUM_RISK_THRESHOLD`
- **low**: below medium threshold

> Cluster score is advisory for ops review only. It does **not** auto-deny claims.

### Ops API

- `GET /api/v1/fraud/runs` — recent cluster generation runs
- `GET /api/v1/fraud/clusters` — flagged or filtered cluster list
- `GET /api/v1/fraud/clusters/{cluster_id}` — cluster members, edges, and metadata
- `POST /api/v1/fraud/clusters/run` — manual generation trigger

## 13. Cell-Tower Cross-Check Signal (GPS Anti-Spoofing)

SaatDin accepts app-observable tower metadata and evaluates it against the worker's claimed zone.

### Mobile telemetry contract

- Endpoint: `POST /api/v1/workers/location-signal`
- Payload fields:
  - `latitude`, `longitude`, `accuracyMeters`, `capturedAt` (optional GPS snapshot)
  - `towerMetadata.servingCell` and optional `towerMetadata.neighborCells[]`
  - each cell can include: `cellId`, `radioType`, `mcc`, `mnc`, `tac`, `signalDbm`, `signalLevel`, and optional `approxLatitude`/`approxLongitude`
  - `towerMetadata.networkZoneHintPincode` (optional network-side zone hint)

### Validation behavior

- Fresh signal required: older than `TOWER_SIGNAL_FRESHNESS_MINUTES` is treated as `stale`.
- When tower coordinates are present, backend computes distance from claimed zone center:
  - near zone -> `match`, higher confidence
  - far from zone -> `mismatch`, lower confidence
- If coordinates are missing, backend can use `networkZoneHintPincode` as a weaker hint (`match_hint` / `mismatch_hint`).
- If no usable tower signal exists, status is `missing` or `insufficient`.

### Fraud scoring contribution + fallback

- Tower signal contribution is additive and bounded:
  - weight: `TOWER_VALIDATION_SCORE_WEIGHT`
  - cap: `TOWER_VALIDATION_ADJUSTMENT_CAP`
- Missing/stale/insufficient tower data stays neutral (no score adjustment).
- Tower signal is advisory only and does **not** auto-deny claims on its own.

## 14. Motion Signal Features (Static-Spoof Separation)

SaatDin supports privacy-safe motion aggregates to distinguish genuine movement from static spoof behavior.

### Contract and collection windows

- Endpoint: `POST /api/v1/workers/location-signal`
- Additional payload object: `motionMetadata`
  - `windowSeconds`
  - `sampleCount`
  - optional aggregate metrics: `movingSeconds`, `stationarySeconds`, `distanceMeters`, `avgSpeedMps`, `maxSpeedMps`, `headingChangeRate`
