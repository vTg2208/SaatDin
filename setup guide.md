# SaatDin Setup Guide

This guide helps you run the SaatDin project locally with both the Flutter app and the FastAPI backend.

## 1. Prerequisites

Install the following tools:
- Flutter SDK (stable)
- Dart SDK (comes with Flutter)
- Python 3.11+
- Android Studio or VS Code + Android SDK
- Git

Verify installation:

```powershell
flutter --version
dart --version
python --version
```

## 2. Project Structure (Important Paths)

- Flutter app source: lib/
- Flutter assets: assets/
- Zone risk data: assets/data/zone_risk_runtime.json
- Backend source: backend/app/main.py
- Backend dependencies: backend/requirements.txt

## 3. Flutter App Setup

From project root, install dependencies:

```powershell
flutter pub get
```

Run the app:

```powershell
flutter run
```

## 4. Backend Setup (FastAPI)

From project root, install backend dependencies:

```powershell
python -m pip install -r backend/requirements.txt
```

Create environment config for Supabase (required):

```powershell
copy backend/.env.example .env
```

Edit `.env` and set:

```env
SUPABASE_DB_URL=postgresql://postgres:<password>@<host>:5432/postgres
```

Optional: migrate existing local SQLite data into Supabase once:

```powershell
python backend/scripts/migrate_sqlite_to_supabase.py --sqlite backend/backend_data.db --supabase-db-url "postgresql://postgres:<password>@<host>:5432/postgres"
```

Start backend server:

```powershell
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
```

Backend base URL expected by app:
- http://localhost:8000/api/v1

## 5. Verify Backend Is Running

Health check:

```powershell
curl http://127.0.0.1:8000/api/v1/health
```

Expected response:

```json
{"status":"ok"}
```

## 6. Current Implemented API Endpoints

- GET /api/v1/health
- POST /api/v1/auth/send-otp
- POST /api/v1/auth/verify-otp
- GET /api/v1/platforms
- GET /api/v1/zones
- GET /api/v1/zones/{pincode}
- GET /api/v1/plans?zone={zone}&platform={platform}
- POST /api/v1/register
- GET /api/v1/triggers/active?zone={zone}

## 7. Run App + Backend Together

1. Terminal A (backend):

```powershell
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
```

2. Terminal B (flutter):

```powershell
flutter run
```

The app will use backend endpoints where available and fallback behavior where needed.

## 8. Troubleshooting

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
- Verify ApiService baseUrl is http://localhost:8000/api/v1
- On emulator/device, localhost mapping may differ

## 9. Useful Dev Commands

```powershell
flutter analyze
flutter test
python -m compileall backend/app/main.py
```

## 10. Notes

- Zone and risk data are currently loaded from assets/data/zone_risk_runtime.json.
- Dynamic onboarding zone selection and plan pricing are integrated.
- Additional Phase 2 modules (persistent DB, scheduled triggers, claims payout flow) can be built on top of this setup.
