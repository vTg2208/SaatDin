# SaatDin

> *Ek hafte ki kamai, hamesha surakshit.*
> A week's earnings, always protected.

This document contains the complete product narrative, architecture, triggers, fraud defense, and design philosophy.

---

## The Problem

Q-commerce delivery riders (Blinkit, Zepto, Swiggy Instamart) in Bangalore operate on week-to-week earnings with no financial safety net. External disruptions — heavy rainfall, hazardous air quality, severe traffic congestion, curfews, and civic strikes — force them off the road entirely, resulting in zero earnings for the day. They bear this loss alone.

Bangalore is the 2nd most congested city globally (2025), with peak-hour speeds dropping below 13.9 kmph. The 2024 monsoon brought 36% excess rainfall. For a rider whose income depends on 10-minute delivery windows, gridlock and flooded zones are *priceable income events*, not just inconveniences.

## The Solution

SaatDin is a parametric income insurance product. Workers pay a small weekly premium. When a qualifying external disruption is detected in their delivery zone, a payout is triggered **automatically** — no claim form, no phone call. The system monitors real-time weather, air quality, and traffic at the **pincode level**, so a flood in Bellandur does not affect a rider in Whitefield.

**Design principle:** Zero friction at the moment of loss. A stranded rider should have money in their account before they've thought to check if they have a claim.

---

## Architecture: TriBrain

SaatDin uses a three-stage decision pipeline orchestrated as a stateful graph using LangGraph. Every claim routes through one of three tiers based on confidence:

### Tier 1 — Rule Engine (Confidence ≥ 0.90)

Hard-coded parametric thresholds. If Open-Meteo returns 52mm rainfall in Bellandur's pincode in the past 3 hours, RainLock fires. Zero API cost, zero latency. This handles the vast majority of genuine, unambiguous claims. Speed matters here.

### Tier 2 — ML Engine (Confidence 0.60–0.89)

- **Isolation Forest** for claims anomaly detection (trained on synthetic normal and fraudulent profiles)
- **GPS validation** against worker's registered zone (variance, distance)
- **Cell tower triangulation** (independent of GPS, requires physical presence)
- **Motion aggregates** (accelerometer/gyroscope to detect static spoofing)
- **Device fingerprinting** (detect multi-account rings)
- **Co-claim graph analysis** (workers claiming in temporal clusters)

Output: fraud score, with input features persisted to the claim record.

### Tier 3 — LLM Brain (Confidence < 0.60)

Groq API running `llama-3.3-70b-versatile`, invoked *only* for genuinely ambiguous fraud cases where Tiers 1 and 2 conflict. **Critical:** Its output feeds a **human review queue**. It does not auto-reject claims. No algorithm unilaterally denies a worker's income claim without a human seeing it first.

---

## Parametric Triggers

All triggers evaluate at **pincode level**. The trigger monitor polls every 15 minutes via APScheduler.

| Trigger | Event | Data Source | Threshold | Payout |
|---|---|---|---|---|
| **RainLock** | Heavy rainfall | Open-Meteo | > 35mm in 3 hours | 100% of daily rate |
| **AQI Guard** | Hazardous air quality | WAQI / data.gov.in | AQI > 250 sustained 4 hours | 80% of daily rate |
| **TrafficBlock** | Severe congestion | TomTom Traffic API | Avg. speed < 5 kmph sustained 2 hours | 70% of daily rate |
| **ZoneLock** | Curfew / bandh / strike | NewsAPI + NLP | Confirmed disruption in zone | 100% of daily rate |
| **HeatBlock** | Extreme heat + humidity | Open-Meteo | Temp > 39°C + humidity > 70% for 4 hours | 60% of daily rate |

HeatBlock is the one we're proudest of conceptually. Every conversation about climate risk and gig workers focuses on floods. Nobody talks about working outdoors in 40°C heat with 75% humidity for eight hours as a genuine occupational health risk with direct earnings consequences. We price it. We cover it.

---

## ZAPE: Zone-Adaptive Pricing Engine

Every Sunday night, ZAPE recalculates each worker's weekly premium for the upcoming week:

$$
P_{\text{weekly}} = R_{\text{base}} \times M_{\text{zone}} \times F_{\text{platform}} \times (1 - D_{\text{loyalty}})
$$

| Symbol | Value / Source |
|---|---|
| $R_{\text{base}}$ | ₹45/week (design assumption) |
| $M_{\text{zone}}$ | Composite risk score: BBMP flood zones, CPCB AQI history, TomTom historical congestion |
| $F_{\text{platform}}$ | 1.1× for Blinkit/Zepto (10-min SLA, higher street exposure); 1.0× for Swiggy Instamart |
| $D_{\text{loyalty}}$ | 5% per clean 4-week streak, capped at 20% |

**Three coverage tiers:**

| Tier | Weekly Premium (est.) | Per-trigger Payout | Max days/week |
|---|---|---|---|
| Basic | ₹35–52 | ₹250/day | 2 |
| Standard | ₹53–68 | ₹400/day | 3 |
| Premium | ₹69–90 | ₹550/day | 4 |

Approximately 0.1–0.3% of a rider's monthly income for a full week of protection.

---

## Archival Data & Cold Storage

The live Supabase/Postgres layer stays intentionally lean, holding only **current-week data plus rolling 4-week streak history** (needed for loyalty discount).

Every Sunday night, a weekly cron job serialises closed-week claims, payouts, and worker records into **S3-compatible cold archive storage**. The same batch mirrors to **BigQuery** for efficient historical queries and actuarial analysis.

**Why this architecture:**
- Production reads stay sub-100ms (hot data only)
- Historical patterns feed back into pricing calibration as real claims accumulate
- Reduces dependence on synthetic training data
- Enables long-term trend analysis for model improvement
- Operational database stays lean, no bloat from historical records

---

## Fraud Detection: Multi-Signal Defense

A coordinated fraud ring of 500 workers using GPS-spoofing apps to fake locations during weather events is a direct threat. SaatDin's answer: a real delivery rider caught in a flood leaves a constellation of device signals that a person sitting safely at home cannot fake simultaneously.

### Layer A — GPS Validation & Zone Affinity

**GPS variance:** Real outdoor GPS drifts 3–15m naturally. Spoofing apps produce unnaturally stable coordinates. Claims where variance < 1m² over 30 minutes are flagged.

**Zone affinity scoring** using Haversine distance from worker's registered zone centre:

$$
A = \begin{cases}
0.95 & d < 2\text{ km} \\
0.70 & 2 \leq d < 5\text{ km} \\
0.40 & 5 \leq d < 10\text{ km} \\
0.20 & d \geq 10\text{ km}
\end{cases}
$$

Claims where $A < 0.25$ are auto-rejected. A genuine Bellandur rider has affinity > 0.90 on normal days.

### Layer B — Cell Tower Cross-Referencing

Every Android device reports its connected towers independently of GPS. A spoofing app cannot fake tower ID without root-level device access (uncommon). At claim time, claimed GPS is cross-referenced against the device's actual tower location. Tower mismatch signals fraud.

### Layer C — Motion Aggregates

A rider navigating a waterlogged road produces irregular motion: speed changes, rapid stops, vibration. A stationary person spoofing from a couch produces near-zero motion variance. We collect privacy-safe motion aggregates (movingSeconds, stationarySeconds, distanceMeters, avgSpeedMps) per claim window.

### Layer D — Device Fingerprinting & Co-Claim Graphs

Device fingerprints (SHA-256 of `device_id|app_version|os_type`) cluster phones to detect multi-account rings. Reject auto-claims if 3+ devices with same fingerprint trigger claims for the same event.

**Co-claim graphs:** Workers who consistently co-trigger claims within minutes across multiple independent events are modeled as weighted edges. Dense subgraphs (clusters of workers always claiming together) surface on the admin dashboard as suspected rings.

---

## The 60% Compromise: Trust Over Precision

**Core principle:** No claim is ever auto-rejected. No genuine worker is left with zero.

When fraud detection flags a claim:

1. **Immediate 60% payout** to worker's UPI account
2. **Neutral notification** — "Your RainLock claim is under review. ₹240 credited. ₹160 follows once verified."
3. **Zone consensus auto-clear** — If 3+ workers with clean 8-week history in the same zone have uncontested claims for the same event, remaining 40% releases automatically
4. **Human review queue** for unresolved cases — 4-hour SLA

**The math:** False positive cost (wrongly delaying a genuine worker) = a few hours + 40% of one daily rate. False negative cost (paying a fraudster) = 60% of one daily rate before detection. Both manageable. Genuine worker never fully blocked.

**Why this matters:** A delivery rider has no relationship with financial services. He's seen chit funds that didn't pay. He's seen investment apps that charged hidden fees. He has zero reason to trust. The 60% immediate payout is not a claims management feature — it's proof of intent. It's how you earn the belief that this time, something actually works.

---

## Implementation Status

### Completed in the Local Build

- Android-first Flutter app with onboarding, policy, claims, payouts, profile flows
- FastAPI backend with OTP auth, worker registration, dynamic ML premium calculation
- Trigger monitoring: 15-minute polling cycle with graceful API fallback
- Sustained-window logic for AQI Guard and TrafficBlock (persisted window history)
- ZoneLock manual verification with auto-confirmation (2+ corroborating reports)
- Fraud scoring: Isolation Forest + GPS/tower/motion/device validation + co-claim graphs
- Weekly archival pipeline for S3 and BigQuery
- Manual claim escalation with human review queue (2-4 hour SLA)
- FastAPI admin dashboard with claim, escalation, fraud cluster visibility
- Local payout sandbox with UPI validation and statement generation

### Operational Follow-up

- Live provider credentials (Groq/Gemini, NewsAPI, WAQI, TomTom, Razorpay)
- Push notifications and production-grade background signal delivery
- CI runners for automated backend + frontend test execution on every push
- Deployment to Railway or hosted infrastructure with monitoring

---

## Design Philosophy

Every architectural decision in SaatDin flows from one core insight: **the cost of doubting a genuine worker far exceeds the cost of paying a fraudster.**

Traditional insurance exists to minimize payouts. Parametric insurance exists to maximize the odds that someone honest gets the money they were promised. We designed every layer — TriBrain, the 60% compromise, the multi-signal fraud architecture, the archival pipeline for real calibration — around minimizing the harm done to legitimate claimants while still protecting the product from coordinated fraud.

That's worth more than any feature roadmap.

---

## Team

T Vishnu Vardhan · D Rohith Kumar · V A B Jashwanth Reddy · V Kireeti · Tejesh Neelam

---

*Premium ranges, zone multipliers, and trigger thresholds are prototype design decisions. They require actuarial calibration before real-world deployment. The product is designed to align with IRDAI guidelines for parametric and micro-insurance products targeting informal sector workers.*
