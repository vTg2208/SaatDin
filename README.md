# SaatDin

> *Ek hafte ki kamai, hamesha surakshit.*
> A week's earnings, always protected.

Parametric income insurance for Q-commerce delivery riders in Bangalore — automatic payouts when external disruptions make work impossible.

---

## What It Does

Riders pay a small weekly premium. When rainfall, air quality, traffic, curfews, or extreme heat disrupt their delivery zone, SaatDin detects the event via real-time APIs and credits a payout to their UPI account **automatically** — no claim form, no phone call, no waiting.

**Triggers are evaluated at pincode level.** A flood in Bellandur does not trigger a payout for a rider in Whitefield.

![SaatDin Architecture](arch.png)

---

## What's Implemented

- **Flutter Android app** — onboarding, policy, claims, payouts
- **FastAPI backend** — OTP auth, premium calculation, trigger monitoring (15-min polling), claims, escalations, admin dashboard
- **Five parametric triggers** — RainLock, AQI Guard, TrafficBlock, ZoneLock, HeatBlock
- **Multi-signal fraud detection** — GPS variance, cell tower validation, motion analysis, device fingerprinting, co-claim graphs
- **Weekly archival pipeline** — closed-week data to S3-compatible cold storage + BigQuery
- **Manual escalation** — 60% immediate payout + human review for ambiguous cases

**For full architecture, fraud defense strategy, and design philosophy, see [PROJECT_INFO.md](PROJECT_INFO.md).**

---

## Archival Storage

The live Supabase/Postgres database keeps only **current-week data + rolling 4-week history** (for loyalty tracking). Every Sunday night, closed-week claims, payouts, and worker records serialize to **S3-compatible cold archive** and mirror to **BigQuery** for long-term actuarial analysis.

This keeps reads sub-100ms while building the historical record needed for pricing calibration as real claims accumulate.

---

## Quick Start

```bash
python -m pip install -r backend/requirements.txt
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
# In another terminal:
flutter run
```

Admin dashboard: `http://127.0.0.1:8000/admin/dashboard` (admin / saatdin-local)  
Full setup: [Setup Guide](setup%20guide.md)

---

## Tech Stack

Backend: Python 3.11, FastAPI, Supabase/Postgres, APScheduler | ML: scikit-learn, LangGraph, Groq | Mobile: Flutter | Archival: S3, BigQuery | Payments: Razorpay sandbox | Deployment: Railway, GitHub Actions

---

## Documentation

- **[PROJECT_INFO.md](PROJECT_INFO.md)** — Architecture, triggers, fraud defense, design philosophy
- **[Setup Guide](setup%20guide.md)** — Local dev and deployment


---

## Team

T Vishnu Vardhan · D Rohith Kumar · V A B Jashwanth Reddy · V Kireeti · Tejesh Neelam

---

*Prototype design. All thresholds and premium ranges require actuarial calibration before real-world deployment.*
