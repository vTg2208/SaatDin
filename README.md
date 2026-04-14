# SaatDin

> *Ek hafte ki kamai, hamesha surakshit.*
> A week's earnings, always protected.

Parametric income insurance for Q-commerce delivery riders in Bangalore — built for the Guidewire DEVTrails 2026 hackathon.

---

## Table of Contents

- [Problem](#problem)
- [Solution](#solution)
- [Policy Exclusions](#policy-exclusions)
- [Persona & Scenarios](#persona--scenarios)
- [Application Workflow](#application-workflow)
- [Weekly Premium Model](#weekly-premium-model)
- [Parametric Triggers](#parametric-triggers)
- [AI & ML Architecture](#ai--ml-architecture)
- [Fraud Detection](#fraud-detection)
- [Adversarial Defense & Anti-Spoofing Strategy](#adversarial-defense--anti-spoofing-strategy)
- [Manual Claim Escalation](#manual-claim-escalation)
- [Local Development](#local-development)
- [Tech Stack](#tech-stack)
- [Delivery Status](#delivery-status)
- [Team](#team)
- [References](#references)

---

## Problem

Q-commerce delivery riders (Blinkit, Zepto, Swiggy Instamart) in Bangalore operate on week-to-week earnings with no financial safety net. External disruptions — heavy rainfall, hazardous air quality, severe traffic congestion, curfews, and civic strikes — force them off the road entirely, resulting in zero earnings for the day. They bear this loss alone, with no recourse.

Bangalore is the 2nd most congested city in the world as of 2025, with average peak-hour speeds dropping to 13.9 kmph and drivers spending over 36 minutes to cover 10 km. [(Source)](https://www.outlooktraveller.com/News/global-traffic-index-2025-indian-cities-among-the-most-congested-on-earth) For a rider whose income depends on completing deliveries within a 10-minute window, gridlock is an income event, not just an inconvenience.

**Coverage scope:** Loss of income only. This platform does not cover health, life, accidents, or vehicle repairs.

---

## Solution

SaatDin is a parametric income insurance platform. Workers pay a small weekly premium. When a qualifying external disruption is detected in their delivery zone, a payout is triggered **automatically** — no claim form, no phone call, no waiting.

The system monitors real-time weather, air quality, and traffic data at the **pincode level**. A flood in Bellandur does not trigger a payout for a rider based in Whitefield. In the rare event the automated system fails, workers have a direct manual escalation path.

**Platform:** Mobile application (Android-first, Flutter).

---

## Policy Exclusions

SaatDin covers **income loss caused by qualifying external disruptions only**. The following are explicitly excluded from all coverage tiers, regardless of their impact on a worker's ability to earn:

| Exclusion Category | Reason |
|---|---|
| Health, illness, or injury | Covered under separate health insurance products; outside scope |
| Life and personal accident | Outside scope by design — income-only coverage |
| Vehicle damage or repair | Rider bears asset risk; not an income-loss event |
| War, armed conflict, or civil war | Force majeure exclusion — standard across all parametric products |
| Government-declared pandemic or epidemic | Systemic, nationwide events cannot be priced at zone level; excluded to prevent adverse selection and actuarial collapse |
| Nuclear, chemical, or biological events | Force majeure exclusion |
| Pre-existing income loss (worker already offline before trigger) | Trigger window must overlap with an active shift; retrospective claims not supported |
| Self-induced disruption | Workers who voluntarily go offline during a non-triggered window are not eligible |
| Platform-side operational failures | App downtime, dark store closures, or platform policy changes are not external disruptions |

**Why pandemic exclusion specifically:** A city-wide pandemic event (as seen in 2020–21) causes correlated income loss across the entire enrolled worker base simultaneously. A parametric platform operating at pincode level cannot price for this correlation without reinsurance support. Pandemic risk is therefore excluded in Phase 1 and Phase 2, with reinsurance-backed pandemic riders identified as a Phase 3 roadmap item.

> This exclusion list is designed to align with IRDAI guidelines for parametric and micro-insurance products targeting informal sector workers.

---

## Persona & Scenarios

**Segment:** Q-commerce delivery riders — Blinkit, Zepto, Swiggy Instamart
**City:** Bangalore
**Earnings reference:** Platform statements put monthly earnings between ₹25,000 and ₹40,000 for active riders. [(Source)](https://www.storyboard18.com/brand-marketing/blinkit-zepto-swiggy-delivery-partners-pay-how-much-do-they-earn-26169.htm)

**Why Bangalore specifically:**
The 2024 monsoon brought Bangalore 36% excess rainfall vs. the long-term average, causing severe waterlogging across 110+ localities. [(Source)](https://www.thehindu.com/news/cities/bangalore/bengaluru-floods-2024/article68623890.ece) Zones like Bellandur, Sarjapur Road, and Marathahalli are chronically affected — the same corridors where Blinkit and Zepto dark stores are concentrated. Compounding this, Bangalore ranked 2nd globally for traffic congestion in 2025, with peak-hour speeds on key delivery corridors like the Outer Ring Road and Silk Board junction dropping below 5 kmph for hours at a time. [(Source)](https://www.outlooktraveller.com/News/global-traffic-index-2025-indian-cities-among-the-most-congested-on-earth) For a Q-commerce rider contractually expected to deliver within 10 minutes, a 3-hour gridlock is functionally equivalent to a flood — their shift earnings drop to zero regardless of the cause.

**Three representative worker profiles:**

| Worker | Platform | Zone | Risk Level | Scenario |
|---|---|---|---|---|
| Raju, 28 | Blinkit | Bellandur | High | Caught in a monsoon flash flood mid-shift. Roads waterlogged. Cannot reach the dark store. |
| Babu, 24 | Zepto | HSR Layout | Medium | AQI crosses 270 during Diwali week. Outdoor work for 8 hours becomes a health risk. |
| Suresh, 32 | Swiggy Instamart | Whitefield | Medium | Outer Ring Road gridlocked for 3 hours due to an infrastructure collapse. Zero deliveries possible. |

---

## Application Workflow

The following describes the end-to-end flow for Raju during a monsoon event on a Tuesday evening.

1. **Onboarding (one time):** Raju downloads the SaatDin app, enters his phone number, and receives an OTP. He selects Blinkit as his platform and Bellandur as his dark store zone. ZAPE calculates his weekly premium at ₹69 and presents three coverage tiers. He selects Standard (₹400/day payout) and consents to a weekly auto-debit from his UPI ID.

2. **Policy activation:** Every Monday morning, Raju's policy for the week is active. He sees his coverage status and the current risk level for his zone on the app home screen. No action required.

3. **Background monitoring:** Every 15 minutes, SaatDin's trigger monitor polls Open-Meteo for rainfall data at Raju's registered pincode (560103 — Bellandur). Raju is unaware of this. He is out making deliveries.

4. **Trigger condition met:** At 6:45 PM, Open-Meteo returns 52mm of rainfall in the past 3 hours for pincode 560103. This crosses the RainLock threshold of 35mm.

5. **TriBrain evaluation:** The rule engine (Tier 1) evaluates the event. Confidence is 0.94 — above the 0.90 threshold. A claim is automatically created for Raju. No human involvement. Elapsed time: under 2 seconds.

6. **Fraud check:** SaatDin evaluates Raju's recent mobile location, GPS variance, and anomaly signals against his registered Bellandur zone. The claim clears without manual review.

7. **Payout initiated:** The payout is dispatched through the local payout sandbox. The backend exposes Razorpay-compatible provider hooks, and live Razorpay keys can be configured later without changing the mobile flow.

8. **Status visible in app:** The payout and claim status become visible in the Flutter app immediately. Push notifications are follow-up work for hosted deployments.

9. **End of day:** The claim is logged. Raju's disruption history is updated, and the same zone-risk inputs remain available for future pricing updates.

---

The following describes the end-to-end flow for Suresh during a severe traffic disruption on a weekday evening.

1. **Background monitoring:** Every 15 minutes, SaatDin's trigger monitor polls the TomTom Traffic API for average vehicle speed in Suresh's registered pincode (560066 — Whitefield). Suresh is mid-shift on the Outer Ring Road corridor.

2. **Trigger condition met:** At 7:10 PM, TomTom returns an average speed of 3.8 kmph for pincode 560066, sustained for the past 2 hours. This crosses the TrafficBlock threshold of less than 5 kmph for 2 sustained hours.

3. **TriBrain evaluation:** The rule engine (Tier 1) evaluates the event. Confidence is 0.91. A claim is automatically created for Suresh. Elapsed time: under 2 seconds.

4. **Fraud check:** SaatDin evaluates Suresh's recent mobile location, tower, and anomaly signals against the Whitefield zone. The claim clears without manual review.

5. **Payout initiated:** The payout is dispatched through the same sandbox payout rail. TrafficBlock pays at 70% since partial deliveries may still be possible on alternate routes.

6. **Status visible in app:** The payout and claim status become visible in the Flutter app immediately. Push notifications are follow-up work for hosted deployments.

7. **End of day:** The claim is logged and the zone's traffic score stays available for later repricing or analytics.

---

## Weekly Premium Model

Premiums are structured on a **weekly basis** to align with the gig economy's typical payout cycle. In the current implementation, ZAPE (Zone-Adaptive Pricing Engine) calculates premiums when a worker registers, changes plan, or fetches policy details. The same pricing inputs are reused consistently across frontend and backend.

```
Weekly Premium = Base Rate x Zone Risk Multiplier x Platform Factor
```

**Base rate:** ₹45/week (design assumption — to be calibrated against real claims data)

**Zone Risk Multiplier** is derived from each pincode's historical flood, AQI, and traffic profile, sourced from BBMP flood zone records, CPCB data, and TomTom historical congestion data.

> The specific multiplier values are our model's design assumptions. They will be updated as real data is incorporated.

**Platform Factor:**
- Blinkit / Zepto (10-minute delivery commitment, higher outdoor exposure): 1.1×
- Swiggy Instamart (30-minute delivery): 1.0×

**Loyalty Discount:** planned follow-up work. It is not applied in the local build yet, so the formula above reflects the current backend behavior.

**Three coverage tiers:**

| Tier | Weekly Premium (est.) | Per-trigger Payout | Max covered days/week |
|---|---|---|---|
| Basic | ₹35–52 | ₹250/day | 2 |
| Standard | ₹53–68 | ₹400/day | 3 |
| Premium | ₹69–90 | ₹550/day | 4 |

> Premium ranges are design estimates.

---

## Parametric Triggers

All triggers are evaluated at the pincode level, not city level. A trigger fires only if the condition is met in the worker's registered delivery zone.

| Trigger | Event | Data Source | Threshold | Payout |
|---|---|---|---|---|
| RainLock | Heavy rainfall | [Open-Meteo](https://open-meteo.com) | > 35mm in 3 hours | 100% of daily rate |
| AQI Guard | Hazardous air quality | [WAQI](https://waqi.info) / data.gov.in | AQI > 250 sustained 4 hours | 80% of daily rate |
| TrafficBlock | Severe congestion | [TomTom Traffic API](https://developer.tomtom.com) (free dev tier) | Average speed < 5 kmph sustained 2 hours in zone | 70% of daily rate |
| ZoneLock | Curfew / bandh / strike | NewsAPI + keyword NLP | Confirmed disruption in zone | 100% of daily rate |
| HeatBlock | Extreme heat + humidity | [Open-Meteo](https://open-meteo.com) | Temp > 39°C + humidity > 70% for 4 hours | 60% of daily rate |

The trigger monitor polls every 15 minutes via APScheduler.

### ZoneLock — Manual Verification Option

ZoneLock is the only trigger that cannot always be verified purely by a sensor feed. Curfews and strikes may be localised, announced late, or not yet covered by news APIs. For this reason, ZoneLock supports a manual verification path in addition to automatic detection:

1. Worker reports a suspected ZoneLock event directly from the app.
2. The submission is timestamped and cross-referenced against available news feeds and other active worker reports in the same zone.
3. If two or more workers independently report the same event within a 30-minute window, ZoneLock is auto-confirmed.
4. If only one report exists, it enters a human review queue on the admin dashboard. Target review SLA: 2 hours.
5. Confirmed payouts are processed retroactively from the time of the first worker report.

---


## Architecture

![SaatDin Architecture Diagram](arch.png)

SaatDin uses a three-tier decision engine called **TriBrain**, orchestrated as a stateful graph using [LangGraph](https://github.com/langchain-ai/langgraph) (open source, Python, free). LangGraph models each decision step — rule check, ML inference, LLM reasoning — as nodes in a directed graph, with edges controlling routing based on confidence scores. This provides human-in-the-loop checkpoints, fault tolerance, and full auditability of every claim decision.

```
Confidence ≥ 0.90  →  Tier 1: Rule Engine     (instant, no model call)
Confidence 0.60–0.89  →  Tier 2: ML Engine   (scikit-learn / XGBoost)
Confidence < 0.60   →  Tier 3: LLM Brain     (Groq API, free tier)
```

### Tier 1 — Rule Engine
Hard-coded parametric rules evaluated as the first graph node. If `rainfall_3hr > 35` and `worker.pincode == event.pincode`, trigger fires immediately. Handles the majority of clear-cut cases with zero latency and zero API cost.

### Tier 2 — ML Engine
A Random Forest model for dynamic premium calculation. An Isolation Forest model for anomaly detection in claims. Both trained on synthetic Bangalore weather and delivery data; will be updated with real data as it becomes available.

Input features for the premium model:
```python
features = [
    'zone_flood_risk_score',         # derived from BBMP data, 0.0–1.0
    'zone_aqi_risk_score',           # derived from CPCB historical data
    'zone_traffic_congestion_score', # derived from TomTom historical average speed data per pincode
    'worker_active_hours_per_week',  # reserved input for future platform telemetry
    'platform_type',                 # 0 = Instamart, 1 = Blinkit/Zepto
    'season',                        # 0 = dry, 1 = pre-monsoon, 2 = monsoon
    'disruption_days_past_4_weeks'   # rolling count
]
```

`zone_traffic_congestion_score` is computed from TomTom's historical traffic flow data for each pincode. Pincodes on major arterial corridors — Outer Ring Road (Whitefield, Marathahalli), Hosur Road (Bommanahalli, Silk Board), and Bannerghatta Road — carry higher baseline congestion scores that directly increase the Zone Risk Multiplier. This means workers based in chronically gridlocked zones pay a slightly higher premium, reflecting the realistic frequency of TrafficBlock events in their area.

### Tier 3 — LLM Brain
[Groq API](https://console.groq.com) running `llama-3.3-70b-versatile` in the cloud. Used only for ambiguous fraud cases where Tiers 1 and 2 disagree.

---

## Fraud Detection

Three layers, each escalating in compute cost:

**Layer A — GPS Validation (rule-based)**
Worker location signals collected from the Flutter app are checked against the registered delivery zone at claim time. GPS variance, jump ratio, and zone affinity feed directly into the fraud score.

**Layer B — Isolation Forest (scikit-learn)**
Detects statistical anomalies across: claim hour, API weather reading at claim time, zone claim density for the day, worker claim frequency over 30 days, GPS distance from store. Trained on synthetic normal and fraudulent claim profiles.

**Layer C — LLM Reasoning (Groq API)**
Triggered only when Layers A and B return conflicting signals. The model receives the full claim context and returns a structured risk assessment. Output is stored for human review — it does not auto-reject claims.

**GPS Spoofing Heuristic:**
Three or more claims submitted from coordinates with less than 1 metre of variance across different days is flagged as a potential spoofing pattern.

---

## Adversarial Defense & Anti-Spoofing Strategy

A coordinated fraud ring of 500 workers using GPS-spoofing applications to fake locations during weather events represents a direct threat to platform liquidity. Basic GPS verification is insufficient against this attack vector. SaatDin addresses this with a multi-signal defense architecture.

### 1. Differentiation — Genuine Stranded Worker vs. Spoofer

A real delivery worker caught in a flood zone leaves a constellation of corroborating device signals that a person sitting safely at home cannot fake simultaneously. SaatDin cross-references GPS against the following:

- **Accelerometer and gyroscope data:** A rider navigating a waterlogged road produces a distinct motion signature — irregular vibration, speed changes, stops. A stationary person spoofing GPS from a couch produces near-zero motion variance. Flutter provides direct access to device sensors; this data is collected passively during an active policy period and is not uploaded unless a claim is evaluated.
- **Cell tower triangulation:** Every Android device logs the cell towers it is currently connected to. This is independent of GPS and requires physical presence in a zone to match. At claim time, we cross-reference the reported GPS coordinate against the cell tower location returned by the device. A GPS-spoofing app cannot fake the cell tower without root-level access, which is uncommon in this demographic.
- **Historical zone affinity:** ZAPE maintains a delivery zone history for each worker based on past claim and activity data. A worker who has consistently operated from Bellandur for six weeks has a high affinity score for that zone. A worker claiming from a zone they have never operated in, during a red-alert event, is flagged regardless of GPS.
- **GPS coordinate variance:** Real outdoor GPS drifts naturally by 3–15 metres over a 30-minute window due to atmospheric and hardware noise. Spoofing applications produce unnaturally stable coordinates. Claims where GPS variance over a 30-minute window is below 1 metre are flagged for further review.


### 2. Coordinated Ring Detection — Data Points Beyond GPS

SaatDin models the fraud ring problem as a graph detection problem, not a single-claim anomaly problem. The following signals are analyzed together:

- **Claim velocity spike detection:** If more than 15 workers in the same pincode submit or receive triggered claims within a 10-minute window, and the weather API reading for that zone is below the red-alert threshold, the event ratio is anomalous. The entire batch is held for review rather than processing individually.
- **TrafficBlock-specific fraud signal:** TrafficBlock is uniquely susceptible to abuse because traffic data is publicly visible — a bad actor can watch TomTom's public map and file a claim the moment congestion crosses the threshold without being anywhere near the zone. SaatDin cross-references the TrafficBlock claim with the worker's GPS trajectory over the preceding 30 minutes. A genuine stranded rider shows slow or stalled movement within the congested corridor. A spoofer at home shows zero movement. Stationary GPS during a claimed TrafficBlock event is a high-confidence fraud signal.
- **Device fingerprint clustering:** Claims submitted from the same device ID, the same advertising ID, or the same IP subnet are automatically linked. Multiple worker accounts operating from a single device or household network constitute a high-confidence ring signal.
- **Temporal co-claim graph:** Workers who consistently trigger claims within minutes of each other across multiple independent events are modeled as a weighted graph. Nodes are workers; edges are co-claim events weighted by frequency and recency. Dense subgraphs — clusters of workers who always claim together — are surfaced on the admin dashboard as suspected rings.
- **New account velocity:** Accounts created within 7 days of a red-alert event and immediately filing claims are held for manual review regardless of GPS data.

### 3. Review Flow for Flagged Claims

The local build keeps flagged claims in an `in_review` state instead of auto-rejecting them.

1. **Auto-created or manual claim is stored:** Trigger or dispute data is recorded immediately with full anomaly features.
2. **Fraud signals are attached:** GPS variance, motion quality, tower consistency, zone affinity, device fingerprint, and co-claim graph context are persisted on the claim.
3. **Admin queue receives the case:** Flagged claims and manual escalations appear in the FastAPI admin dashboard for review.
4. **Admin approves or rejects:** An approved claim is settled and routed into the payout sandbox. A rejected claim remains visible in claim history with its final status.
5. **Operational follow-up:** Push notifications and partial-provisional payouts are follow-up roadmap items, not part of the current local build.

This keeps the decision trail auditable while ensuring every flagged claim has a visible review path and no silent failure mode.

---

## Manual Claim Escalation

Parametric systems are not infallible. Sensor APIs can fail, data can be delayed, and edge cases exist that no rule set anticipates. SaatDin provides a structured escalation path for workers when the automated system does not trigger a payout they believe they are entitled to.

**Escalation flow:**

1. Worker taps "Raise a dispute" from the claims screen in the app.
2. Worker provides a brief text reason for the missed or disputed trigger. The current mobile flow captures structured text only.
3. Submission is automatically cross-referenced against available API data for that pincode and time window.
4. If API data supports the claim, payout is approved immediately and the system flags a false-negative for model improvement.
5. If API data is inconclusive, the claim enters a human review queue on the admin dashboard. Target review SLA in the current build: 2 hours.
6. Worker sees the updated claim status in the app and receives payout once resolved.

This ensures that a failed API or an unlisted disruption type does not leave a worker without recourse.

---

## Local Development

SaatDin now runs locally in a **SQLite-first** configuration. No Supabase project is required for day-to-day development.

1. Copy `backend/.env.example` to `backend/.env` if you want to override defaults.
2. Install backend dependencies:

```powershell
python -m pip install -r backend/requirements.txt
```

3. Start the FastAPI backend:

```powershell
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
```

4. Install Flutter packages and run the app from the repository root:

```powershell
flutter pub get
flutter run
```

The worker app talks to `http://localhost:8000/api/v1`, and the admin dashboard is served from `http://127.0.0.1:8000/admin/dashboard`.
Default admin credentials for local review are `admin` / `saatdin-local`.

Optional migration or hosted deployment scripts can still target Supabase later, but they are no longer required for local setup.

On Windows, you can also use a single helper command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start-local.ps1
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend API | Python 3.11, FastAPI |
| Agent orchestration | [LangGraph](https://github.com/langchain-ai/langgraph) (open source) |
| Database (local dev) | SQLite |
| Database (optional hosted target) | Supabase migration scripts |
| Task scheduling | APScheduler |
| ML models | scikit-learn |
| NLP (ZoneLock) | Lightweight keyword + similarity classifier |
| LLM — primary | Groq API, free tier (no credit card) |
| LLM — fallback | Google AI Studio / Gemini 2.5 Flash, free tier (no credit card) |
| Mobile app | Flutter (Android-first) |
| Payment sandbox | Local Razorpay-compatible sandbox service |
| Admin surface | FastAPI HTML dashboard |
| Deployment | Railway free tier |
| CI | GitHub Actions |

**Why mobile and not web:**
Q-commerce riders have no access to a desktop during their shift. Every interaction with SaatDin — checking coverage, receiving a payout notification, raising a dispute — happens between deliveries, on a bike, in under 30 seconds. A mobile app is the only viable form factor for this demographic. Flutter gives us a single codebase for Android and iOS, keeping Phase 2 scope manageable. Push notifications are planned for hosted deployments, and the current local build keeps claim and payout status visible directly inside the app. Native mobile remains the right long-term fit for reliable background signal capture, permissions, and future notification delivery on low-end Android devices. Future scope includes surfacing payout status directly inside platform apps like Blinkit and Zepto through their rider-facing interfaces.

---

## Delivery Status

### Completed in the local build
- Android-first Flutter client with onboarding, policy, claims, payout, and profile flows
- FastAPI backend with OTP auth, worker registration, policy pricing, trigger monitoring, claims, escalations, payouts, and admin review
- Sustained-window trigger logic for AQI Guard, TrafficBlock, and HeatBlock with persisted historical readings
- ZoneLock manual reporting with auto-confirmation when corroborating worker reports arrive in the same zone
- Fraud scoring with Isolation Forest, Groq/Gemini fallback review, GPS variance, motion, tower, zone affinity, device fingerprint, and co-claim graph signals
- Local payout sandbox with UPI validation, transfer tracking, and statement generation
- FastAPI admin dashboard for claims, escalations, fraud clusters, and payout activity

### Follow-up operational work
- Configure live provider credentials for hosted SMS, Groq/Gemini, News, WAQI, TomTom, and Razorpay environments
- Add push notifications and production-grade background delivery for mobile signals
- Wire CI runners with Python and Flutter so the full backend and frontend test suite executes automatically on every change

---

## Team

Behind the scene workers.

| Crew |
|---|
| T Vishnu Vardhan |
| D Rohith Kumar |
| V A B Jashwanth Reddy |
| V Kireeti |
| Tejesh Neelam |

---

*Premium ranges, zone risk multipliers, and trigger thresholds are design decisions made for this prototype. They are not derived from actuarial data and will require calibration before any real-world deployment.*









