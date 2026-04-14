from __future__ import annotations

import argparse
import asyncio
import json
import sqlite3
from datetime import date, datetime, time
from pathlib import Path
from typing import Dict, List, Tuple

import asyncpg

TABLES_IN_ORDER = [
    "otp_codes",
    "workers",
    "worker_location_signals",
    "worker_location_signal_events",
    "claims",
    "claim_escalations",
    "zonelock_reports",
    "trigger_signal_readings",
    "payout_transfers",
    "admin_actions",
    "fraud_cluster_runs",
    "fraud_co_claim_clusters",
    "fraud_co_claim_cluster_members",
    "fraud_co_claim_cluster_edges",
]

JSON_COLUMNS = {
    "worker_location_signals": {"tower_metadata_json", "motion_metadata_json"},
    "worker_location_signal_events": {"tower_metadata_json", "motion_metadata_json"},
    "claims": {"anomaly_features_json", "llm_decision_json", "llm_attempts_json"},
    "trigger_signal_readings": {"metadata_json"},
    "payout_transfers": {"metadata_json"},
    "admin_actions": {"details_json"},
    "fraud_co_claim_clusters": {"supporting_metadata_json"},
    "fraud_co_claim_cluster_edges": {"supporting_metadata_json"},
}


def _sqlite_conn(sqlite_path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(sqlite_path)
    conn.row_factory = sqlite3.Row
    return conn


def table_exists(conn: sqlite3.Connection, table_name: str) -> bool:
    row = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
        (table_name,),
    ).fetchone()
    return row is not None


def read_rows(sqlite_path: Path, table_name: str) -> Tuple[List[str], List[sqlite3.Row]]:
    conn = _sqlite_conn(sqlite_path)
    try:
        cursor = conn.execute(f"SELECT * FROM {table_name}")
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description or []]
        return columns, rows
    finally:
        conn.close()


def _normalize_value(
    table_name: str,
    column_name: str,
    value,
    column_types: Dict[str, str],
):
    if value is None:
        return None

    column_type = (column_types.get(column_name) or "").lower()

    if column_name in JSON_COLUMNS.get(table_name, set()) and isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return text

    if column_type in {"boolean"} and isinstance(value, (int, str)):
        if isinstance(value, int):
            return bool(value)
        lowered = value.strip().lower()
        if lowered in {"1", "true", "t", "yes", "y"}:
            return True
        if lowered in {"0", "false", "f", "no", "n"}:
            return False

    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None

        if column_type in {"timestamp with time zone", "timestamp without time zone"}:
            parsed = text.replace("Z", "+00:00")
            try:
                return datetime.fromisoformat(parsed)
            except ValueError:
                return value

        if column_type == "date":
            candidate = text[:10]
            try:
                return date.fromisoformat(candidate)
            except ValueError:
                return value

        if column_type in {"time without time zone", "time with time zone"}:
            candidate = text.replace("Z", "+00:00")
            try:
                return time.fromisoformat(candidate)
            except ValueError:
                return value

    return value


async def truncate_table(pool: asyncpg.Pool, table_name: str) -> None:
    async with pool.acquire() as conn:
        await conn.execute(f'TRUNCATE TABLE "{table_name}" RESTART IDENTITY CASCADE')


async def target_table_exists(pool: asyncpg.Pool, table_name: str) -> bool:
    query = (
        "SELECT EXISTS ("
        "SELECT 1 FROM information_schema.tables "
        "WHERE table_schema = 'public' AND table_name = $1"
        ")"
    )
    async with pool.acquire() as conn:
        value = await conn.fetchval(query, table_name)
    return bool(value)


async def get_target_columns(pool: asyncpg.Pool, table_name: str) -> List[str]:
    query = (
        "SELECT column_name "
        "FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = $1 "
        "ORDER BY ordinal_position"
    )
    async with pool.acquire() as conn:
        rows = await conn.fetch(query, table_name)
    return [str(row["column_name"]) for row in rows]


async def get_target_column_types(pool: asyncpg.Pool, table_name: str) -> Dict[str, str]:
    query = (
        "SELECT column_name, data_type "
        "FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = $1"
    )
    async with pool.acquire() as conn:
        rows = await conn.fetch(query, table_name)
    return {str(row["column_name"]): str(row["data_type"]) for row in rows}


async def sync_table_sequences(pool: asyncpg.Pool, table_name: str, columns: List[str]) -> None:
    sequence_query = "SELECT pg_get_serial_sequence($1, $2)"
    setval_query = "SELECT setval($1, GREATEST(COALESCE(MAX({col}), 0), 1), true) FROM \"{table}\""

    async with pool.acquire() as conn:
        for column in columns:
            seq_name = await conn.fetchval(sequence_query, table_name, column)
            if not seq_name:
                continue
            await conn.execute(setval_query.format(col=column, table=table_name), seq_name)


async def write_rows(
    pool: asyncpg.Pool,
    table_name: str,
    columns: List[str],
    rows: List[sqlite3.Row],
    column_types: Dict[str, str],
) -> int:
    if not rows or not columns:
        return 0

    col_list = ", ".join([f'"{col}"' for col in columns])
    placeholders = ", ".join([f"${i}" for i in range(1, len(columns) + 1)])
    query = f'INSERT INTO "{table_name}" ({col_list}) VALUES ({placeholders})'

    async with pool.acquire() as conn:
        async with conn.transaction():
            for row in rows:
                values = [
                    _normalize_value(table_name, col, row[col], column_types) for col in columns
                ]
                await conn.execute(query, *values)

    return len(rows)


async def upsert_zone_risk_from_asset(pool: asyncpg.Pool, asset_path: Path) -> int:
    if not asset_path.exists():
        return 0

    raw = json.loads(asset_path.read_text(encoding="utf-8"))
    pincodes = raw.get("pincodes", {})
    if not isinstance(pincodes, dict):
        return 0

    query = (
        "INSERT INTO zone_risk (pincode, zone_json) VALUES ($1, $2::jsonb) "
        "ON CONFLICT (pincode) DO UPDATE SET zone_json = EXCLUDED.zone_json"
    )

    count = 0
    async with pool.acquire() as conn:
        async with conn.transaction():
            for pincode, zone_json in pincodes.items():
                await conn.execute(query, str(pincode), json.dumps(zone_json))
                count += 1
    return count


async def count_rows(pool: asyncpg.Pool, table_name: str) -> int:
    async with pool.acquire() as conn:
        value = await conn.fetchval(f'SELECT COUNT(*) FROM "{table_name}"')
        return int(value or 0)


async def migrate(
    sqlite_path: Path,
    supabase_db_url: str,
    *,
    truncate: bool,
    verify: bool,
    zone_asset_path: Path,
) -> None:
    pool = await asyncpg.create_pool(dsn=supabase_db_url, min_size=1, max_size=3)
    try:
        if truncate:
            for table_name in reversed(TABLES_IN_ORDER):
                if not await target_table_exists(pool, table_name):
                    print(f"skip truncate {table_name}: missing in target")
                    continue
                await truncate_table(pool, table_name)
            if await target_table_exists(pool, "zone_risk"):
                await truncate_table(pool, "zone_risk")
            else:
                print("skip truncate zone_risk: missing in target")

        sqlite_conn = _sqlite_conn(sqlite_path)
        try:
            for table_name in TABLES_IN_ORDER:
                if not table_exists(sqlite_conn, table_name):
                    print(f"skip {table_name}: missing in sqlite")
                    continue
                source_columns, rows = read_rows(sqlite_path, table_name)
                if not await target_table_exists(pool, table_name):
                    print(f"skip {table_name}: missing in target")
                    continue
                target_columns = await get_target_columns(pool, table_name)
                target_column_types = await get_target_column_types(pool, table_name)
                writable_columns = [col for col in source_columns if col in target_columns]
                dropped_columns = [col for col in source_columns if col not in target_columns]
                if dropped_columns:
                    print(
                        f"note {table_name}: skipping source-only columns {', '.join(dropped_columns)}"
                    )
                count = await write_rows(
                    pool,
                    table_name,
                    writable_columns,
                    rows,
                    target_column_types,
                )
                await sync_table_sequences(pool, table_name, writable_columns)
                print(f"migrated {count} rows from {table_name}")
        finally:
            sqlite_conn.close()

        if await target_table_exists(pool, "zone_risk"):
            zone_count = await upsert_zone_risk_from_asset(pool, zone_asset_path)
            print(f"upserted {zone_count} rows into zone_risk from {zone_asset_path}")
        else:
            print("skip zone_risk import: missing in target")

        if verify:
            print("verification summary:")
            for table_name in TABLES_IN_ORDER:
                if not await target_table_exists(pool, table_name):
                    print(f"  {table_name}: skipped (missing in target)")
                    continue
                total = await count_rows(pool, table_name)
                print(f"  {table_name}: {total}")
            if await target_table_exists(pool, "zone_risk"):
                zone_total = await count_rows(pool, "zone_risk")
                print(f"  zone_risk: {zone_total}")
            else:
                print("  zone_risk: skipped (missing in target)")

        print("migration complete")
    finally:
        await pool.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migrate local SQLite data into Supabase Postgres")
    parser.add_argument("--sqlite", required=True, help="Path to existing SQLite db file")
    parser.add_argument("--supabase-db-url", required=True, help="Supabase Postgres connection URL")
    parser.add_argument("--truncate", action="store_true", help="Truncate target tables before migrating")
    parser.add_argument("--verify", action="store_true", help="Print row counts after migration")
    parser.add_argument(
        "--zone-asset",
        default="assets/data/zone_risk_runtime.json",
        help="Path to runtime zone risk JSON asset",
    )
    args = parser.parse_args()

    sqlite_db = Path(args.sqlite).resolve()
    if not sqlite_db.exists():
        raise FileNotFoundError(f"SQLite file not found: {sqlite_db}")

    zone_asset = Path(args.zone_asset).resolve()

    asyncio.run(
        migrate(
            sqlite_db,
            args.supabase_db_url,
            truncate=bool(args.truncate),
            verify=bool(args.verify),
            zone_asset_path=zone_asset,
        )
    )
