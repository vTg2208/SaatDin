from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import HTMLResponse

from ..core.db import (
    create_admin_action,
    get_claim,
    get_latest_fraud_cluster_run,
    get_worker,
    list_claim_escalations,
    list_claims,
    list_fraud_clusters,
    update_claim_status,
    update_escalation_status,
)
from ..core.dependencies import get_admin_actor
from ..core.zone_cache import refresh_zone_cache
from ..models.schemas import ApiResponse, ClaimReviewRequest
from ..services.payouts import initiate_claim_payout, list_admin_payouts

router = APIRouter(tags=["admin"])


def _dashboard_html() -> str:
    return """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>SaatDin Admin</title>
  <style>
    body { font-family: ui-sans-serif, system-ui, sans-serif; margin: 0; background: #f5f7f4; color: #1f2933; }
    header { padding: 24px 28px; background: linear-gradient(135deg, #163b2f, #245746); color: white; }
    main { padding: 20px 28px 36px; display: grid; gap: 18px; }
    section { background: white; border-radius: 18px; padding: 18px; box-shadow: 0 6px 18px rgba(16,24,40,.06); }
    h1, h2 { margin: 0 0 10px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { text-align: left; padding: 10px 8px; border-bottom: 1px solid #e7ecf0; font-size: 14px; vertical-align: top; }
    button { border: 0; border-radius: 999px; padding: 8px 12px; cursor: pointer; font-weight: 600; }
    .approve { background: #d8f3dc; color: #146c2e; }
    .reject { background: #fee2e2; color: #991b1b; }
    .refresh { background: #dbeafe; color: #1d4ed8; }
    .grid { display: grid; gap: 18px; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); }
    pre { white-space: pre-wrap; background: #0f172a; color: #e2e8f0; padding: 14px; border-radius: 12px; overflow: auto; }
    .pill { display: inline-block; padding: 3px 8px; border-radius: 999px; background: #ecfdf3; color: #067647; font-size: 12px; font-weight: 700; }
  </style>
</head>
<body>
  <header>
    <h1>SaatDin Admin Dashboard</h1>
    <p>Review flagged claims, handle escalations, inspect fraud clusters, and confirm payouts.</p>
  </header>
  <main>
    <section>
      <button class="refresh" onclick="loadAll()">Refresh Dashboard</button>
      <span id="status" style="margin-left:12px;color:#667085;"></span>
    </section>
    <div class="grid">
      <section>
        <h2>Claims Review</h2>
        <table id="claims-table"></table>
      </section>
      <section>
        <h2>Escalations</h2>
        <table id="escalations-table"></table>
      </section>
    </div>
    <div class="grid">
      <section>
        <h2>Fraud Clusters</h2>
        <table id="clusters-table"></table>
      </section>
      <section>
        <h2>Payout Activity</h2>
        <table id="payouts-table"></table>
      </section>
    </div>
  </main>
  <script>
    async function fetchJson(path, options = {}) {
      const res = await fetch(path, { headers: { "Content-Type": "application/json" }, ...options });
      if (!res.ok) {
        const text = await res.text();
        throw new Error(text || `Request failed: ${res.status}`);
      }
      return res.json();
    }

    function renderTable(elementId, headers, rows) {
      const table = document.getElementById(elementId);
      table.innerHTML = "";
      const thead = document.createElement("thead");
      const headRow = document.createElement("tr");
      headers.forEach((header) => {
        const th = document.createElement("th");
        th.textContent = header;
        headRow.appendChild(th);
      });
      thead.appendChild(headRow);
      table.appendChild(thead);
      const tbody = document.createElement("tbody");
      rows.forEach((cells) => {
        const row = document.createElement("tr");
        cells.forEach((cell) => {
          const td = document.createElement("td");
          if (cell instanceof HTMLElement) {
            td.appendChild(cell);
          } else {
            td.innerHTML = cell;
          }
          row.appendChild(td);
        });
        tbody.appendChild(row);
      });
      table.appendChild(tbody);
    }

    async function reviewClaim(claimId, status) {
      const reviewNotes = window.prompt(`Review notes for claim ${claimId}:`, "");
      if (reviewNotes === null) return;
      await fetchJson(`/admin/claims/${claimId}/review`, {
        method: "POST",
        body: JSON.stringify({ status, reviewNotes }),
      });
      await loadAll();
    }

    async function loadAll() {
      document.getElementById("status").textContent = "Loading...";
      try {
        const [claims, escalations, clusters, payouts] = await Promise.all([
          fetchJson("/admin/claims?limit=20"),
          fetchJson("/admin/escalations?limit=20"),
          fetchJson("/admin/clusters?limit=20"),
          fetchJson("/admin/payouts?limit=20"),
        ]);

        renderTable("claims-table",
          ["Claim", "Worker", "Status", "Amount", "Actions"],
          (claims.data || []).map((item) => {
            const actions = document.createElement("div");
            actions.style.display = "flex";
            actions.style.gap = "8px";
            const approve = document.createElement("button");
            approve.className = "approve";
            approve.textContent = "Approve";
            approve.onclick = () => reviewClaim(item.id, "approved");
            const reject = document.createElement("button");
            reject.className = "reject";
            reject.textContent = "Reject";
            reject.onclick = () => reviewClaim(item.id, "rejected");
            actions.appendChild(approve);
            actions.appendChild(reject);
            return [
              `#${item.id}<br><small>${item.claim_type}</small>`,
              `${item.phone}<br><small>${item.zone_pincode}</small>`,
              `<span class="pill">${item.status}</span>`,
              `₹${Number(item.amount).toFixed(0)}`,
              actions,
            ];
          })
        );

        renderTable("escalations-table",
          ["Escalation", "Claim", "Worker", "Status", "Reason"],
          (escalations.data || []).map((item) => [
            `#${item.id}`,
            `#${item.claim_id}`,
            item.phone,
            `<span class="pill">${item.status}</span>`,
            item.reason,
          ])
        );

        renderTable("clusters-table",
          ["Cluster", "Risk", "Members", "Events", "Run"],
          (clusters.data || []).map((item) => [
            item.clusterKey || item.cluster_key,
            `<span class="pill">${item.riskLevel || item.risk_level}</span>`,
            item.memberCount || item.member_count,
            item.eventCount || item.event_count,
            item.runId || item.run_id,
          ])
        );

        renderTable("payouts-table",
          ["Transfer", "Worker", "Amount", "Status", "UPI"],
          (payouts.data || []).map((item) => [
            item.providerPayoutId,
            item.claimId ? `Claim #${item.claimId}` : "-",
            `₹${Number(item.amount).toFixed(0)}`,
            `<span class="pill">${item.status}</span>`,
            item.maskedUpiId,
          ])
        );

        document.getElementById("status").textContent = `Last refreshed ${new Date().toLocaleTimeString()}`;
      } catch (error) {
        document.getElementById("status").textContent = error.message;
      }
    }

    loadAll();
  </script>
</body>
</html>
    """


@router.get("/dashboard", response_class=HTMLResponse)
async def admin_dashboard(_: str = Depends(get_admin_actor)) -> HTMLResponse:
    return HTMLResponse(_dashboard_html())


@router.get("/claims", response_model=ApiResponse)
async def admin_claims(
    status: Optional[str] = Query(default=None),
    limit: int = Query(default=50, ge=1, le=500),
    _: str = Depends(get_admin_actor),
) -> ApiResponse:
    rows = await list_claims(status=status, limit=limit)
    return ApiResponse(success=True, data=rows)


@router.get("/escalations", response_model=ApiResponse)
async def admin_escalations(
    status: Optional[str] = Query(default=None),
    limit: int = Query(default=50, ge=1, le=500),
    _: str = Depends(get_admin_actor),
) -> ApiResponse:
    rows = await list_claim_escalations(status=status, limit=limit)
    return ApiResponse(success=True, data=rows)


@router.get("/clusters", response_model=ApiResponse)
async def admin_clusters(
    limit: int = Query(default=50, ge=1, le=500),
    flaggedOnly: bool = Query(default=True),
    _: str = Depends(get_admin_actor),
) -> ApiResponse:
    latest_run = await get_latest_fraud_cluster_run()
    run_id = int(latest_run["id"]) if latest_run else None
    rows = await list_fraud_clusters(run_id=run_id, flagged_only=flaggedOnly, limit=limit, offset=0)
    return ApiResponse(success=True, data=rows)


@router.get("/payouts", response_model=ApiResponse)
async def admin_payouts(
    limit: int = Query(default=50, ge=1, le=500),
    _: str = Depends(get_admin_actor),
) -> ApiResponse:
    rows = await list_admin_payouts(limit=limit)
    return ApiResponse(success=True, data=rows)


@router.post("/cache/zones/refresh", response_model=ApiResponse)
async def admin_refresh_zone_cache(_: str = Depends(get_admin_actor)) -> ApiResponse:
  zone_map = await refresh_zone_cache()
  return ApiResponse(
    success=True,
    data={"zoneCount": len(zone_map)},
    message="Zone cache refreshed",
  )


@router.post("/claims/{claim_id}/review", response_model=ApiResponse)
async def review_claim(
    claim_id: int,
    payload: ClaimReviewRequest,
    admin_actor: str = Depends(get_admin_actor),
) -> ApiResponse:
    claim = await get_claim(claim_id)
    if claim is None:
        raise HTTPException(status_code=404, detail=f"Claim {claim_id} not found")

    normalized_status = payload.status.strip().lower()
    if normalized_status in {"approved", "approve", "settled"}:
        updated = await update_claim_status(
            claim_id,
            status="settled",
            review_notes=payload.reviewNotes,
            reviewed_by=admin_actor,
        )
        worker = await get_worker(str(claim["phone"]))
        transfer = None
        if worker is not None and updated is not None:
          try:
            transfer = await initiate_claim_payout(
              claim=updated,
              worker=worker,
              note=payload.reviewNotes or "Admin approved claim payout",
              metadata={"reviewedBy": admin_actor},
            )
          except ValueError as exc:
            transfer = None
            updated = await update_claim_status(
              claim_id,
              status="in_review",
              review_notes=f"Payout blocked: {exc}",
              reviewed_by=admin_actor,
            )
        if payload.escalationId:
            await update_escalation_status(payload.escalationId, "resolved", payload.reviewNotes)
        await create_admin_action(
            actor=admin_actor,
            action_type="claim_approved",
            claim_id=claim_id,
            escalation_id=payload.escalationId,
            details={"reviewNotes": payload.reviewNotes},
        )
        return ApiResponse(success=True, data={"claim": updated, "transfer": transfer}, message="Claim approved")

    if normalized_status in {"rejected", "reject"}:
        updated = await update_claim_status(
            claim_id,
            status="rejected",
            review_notes=payload.reviewNotes,
            reviewed_by=admin_actor,
        )
        if payload.escalationId:
            await update_escalation_status(payload.escalationId, "rejected", payload.reviewNotes)
        await create_admin_action(
            actor=admin_actor,
            action_type="claim_rejected",
            claim_id=claim_id,
            escalation_id=payload.escalationId,
            details={"reviewNotes": payload.reviewNotes},
        )
        return ApiResponse(success=True, data={"claim": updated}, message="Claim rejected")

    updated = await update_claim_status(
        claim_id,
        status="in_review",
        review_notes=payload.reviewNotes,
        reviewed_by=admin_actor,
    )
    await create_admin_action(
        actor=admin_actor,
        action_type="claim_marked_in_review",
        claim_id=claim_id,
        escalation_id=payload.escalationId,
        details={"reviewNotes": payload.reviewNotes},
    )
    return ApiResponse(success=True, data={"claim": updated}, message="Claim kept in review")
