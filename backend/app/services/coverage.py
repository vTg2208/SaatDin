from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Any, Iterable

from ..core import db


def coverage_week_start(value: datetime | None = None) -> date:
    current = value or datetime.now(timezone.utc)
    if current.tzinfo is None:
        current = current.replace(tzinfo=timezone.utc)
    current_date = current.astimezone(timezone.utc).date()
    return current_date - timedelta(days=current_date.weekday())


def payment_covers_week(payment_rows: Iterable[dict[str, Any]], week_start: date) -> bool:
    for row in payment_rows:
        raw_week_start = row.get("week_start_date")
        if raw_week_start is None:
            continue
        if isinstance(raw_week_start, datetime):
            parsed = raw_week_start.date()
        elif isinstance(raw_week_start, date):
            parsed = raw_week_start
        else:
            try:
                parsed = date.fromisoformat(str(raw_week_start)[:10])
            except (TypeError, ValueError):
                continue
        if parsed == week_start:
            return True
    return False


async def has_active_coverage(phone: str, at: datetime | None = None) -> bool:
    payment_rows = await db.list_paid_premium_weeks_for_phone(phone)
    return payment_covers_week(payment_rows, coverage_week_start(at))
