#!/usr/bin/env python3
"""
stream_telemetry.py — Stream simulated vehicle telemetry into an Iceberg V3 table
via the Snowpipe Streaming Python SDK.

Reads connection credentials from the Snow CLI config.toml file using the
CLI_CONNECTION_NAME environment variable.

Usage:
    python3 stream_telemetry.py --events 100

Environment variables (required):
    CLI_CONNECTION_NAME  — Snow CLI connection name (resolves account/user/key from config.toml)
    DEMO_DATABASE_NAME   — Target database
    DEMO_SCHEMA_NAME_BRONZE — Target schema (bronze layer)

The target table is: <DEMO_DATABASE_NAME>.<DEMO_SCHEMA_NAME_BRONZE>.VEHICLE_TELEMETRY_STREAM
"""

import argparse
import os
import random
import sys
import time
from pathlib import Path
from typing import Any

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib  # type: ignore[no-redef]

from snowpipe_streaming.client import SnowpipeStreamingClient


# ─── Configuration ────────────────────────────────────────────────────────────

TARGET_TABLE = "VEHICLE_TELEMETRY_STREAM"
BATCH_SIZE = 10
BATCH_DELAY_SECONDS = 0.5

# Simulated fleet
VEHICLE_IDS = [f"VH-{i:04d}" for i in range(1, 21)]  # 20 vehicles


# ─── Snow CLI config parsing ─────────────────────────────────────────────────

def find_config_toml() -> Path:
    """Locate the Snow CLI config.toml file."""
    candidates = [
        Path.home() / ".snowflake" / "config.toml",
        Path.home() / ".snowflake" / "connections.toml",
    ]
    for path in candidates:
        if path.exists():
            return path
    raise FileNotFoundError(
        "Could not find Snow CLI config at ~/.snowflake/config.toml or connections.toml"
    )


def load_connection(connection_name: str) -> dict[str, str]:
    """
    Parse the Snow CLI config.toml and return connection details for the
    given connection name.

    Returns dict with keys: account, user, role, private_key_path
    """
    config_path = find_config_toml()
    with open(config_path, "rb") as f:
        config = tomllib.load(f)

    # config.toml uses [connections.<name>]
    connections = config.get("connections", {})
    if connection_name not in connections:
        available = ", ".join(connections.keys()) if connections else "(none)"
        raise KeyError(
            f"Connection '{connection_name}' not found in {config_path}. "
            f"Available: {available}"
        )

    conn = connections[connection_name]

    # Resolve private key path — field may be 'private_key_path' or 'private_key_file'
    key_path = conn.get("private_key_path") or conn.get("private_key_file")
    if not key_path:
        raise ValueError(
            f"Connection '{connection_name}' has no private_key_path or private_key_file. "
            "Snowpipe Streaming requires key-pair authentication."
        )

    return {
        "account": conn["account"],
        "user": conn["user"],
        "role": conn.get("role", "PUBLIC"),
        "private_key_path": key_path,
    }


# ─── Telemetry data generation ───────────────────────────────────────────────

def generate_telemetry_event(vehicle_id: str) -> dict[str, Any]:
    """Generate a realistic vehicle telemetry reading."""
    return {
        "vehicle_id": vehicle_id,
        "telemetry": {
            "speed_mph": round(random.uniform(0, 85), 1),
            "latitude": round(random.uniform(25.0, 48.0), 6),
            "longitude": round(random.uniform(-125.0, -70.0), 6),
            "fuel_level_pct": round(random.uniform(5, 100), 1),
            "engine_temp_f": round(random.uniform(180, 230), 1),
            "rpm": random.randint(600, 6500),
            "heading_deg": round(random.uniform(0, 360), 1),
            "odometer_miles": random.randint(1000, 150000),
            "tire_pressure_psi": {
                "front_left": round(random.uniform(30, 36), 1),
                "front_right": round(random.uniform(30, 36), 1),
                "rear_left": round(random.uniform(30, 36), 1),
                "rear_right": round(random.uniform(30, 36), 1),
            },
            "diagnostic_codes": random.choices(
                ["P0000", "P0171", "P0300", "P0420", "P0440", "P0500"],
                k=random.randint(0, 2),
            ),
        },
    }


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Stream simulated vehicle telemetry via Snowpipe Streaming SDK"
    )
    parser.add_argument(
        "--events", type=int, default=100,
        help="Number of telemetry events to stream (default: 100)"
    )
    args = parser.parse_args()

    # Read environment
    connection_name = os.environ.get("CLI_CONNECTION_NAME")
    database = os.environ.get("DEMO_DATABASE_NAME")
    schema = os.environ.get("DEMO_SCHEMA_NAME_BRONZE")

    if not connection_name:
        print("Error: CLI_CONNECTION_NAME environment variable not set", file=sys.stderr)
        sys.exit(1)
    if not database:
        print("Error: DEMO_DATABASE_NAME environment variable not set", file=sys.stderr)
        sys.exit(1)
    if not schema:
        print("Error: DEMO_SCHEMA_NAME_BRONZE environment variable not set", file=sys.stderr)
        sys.exit(1)

    # Resolve connection credentials from Snow CLI config
    print(f"Resolving connection '{connection_name}' from Snow CLI config...")
    conn = load_connection(connection_name)

    print(f"  Account:  {conn['account']}")
    print(f"  User:     {conn['user']}")
    print(f"  Role:     {conn['role']}")
    print(f"  Key:      {conn['private_key_path']}")
    print(f"  Target:   {database}.{schema}.{TARGET_TABLE}")
    print(f"  Events:   {args.events}")
    print()

    # Create Snowpipe Streaming client
    client = SnowpipeStreamingClient(
        account=conn["account"],
        user=conn["user"],
        private_key_path=conn["private_key_path"],
        role=conn["role"],
    )

    # Open a channel for the target table
    channel = client.open_channel(
        name="vehicle_telemetry_channel_1",
        database=database,
        schema=schema,
        table=TARGET_TABLE,
    )

    print(f"Channel opened: {channel.name}")
    print(f"Streaming {args.events} events in batches of {BATCH_SIZE}...\n")

    total_inserted = 0
    start_time = time.time()

    for batch_start in range(0, args.events, BATCH_SIZE):
        batch_end = min(batch_start + BATCH_SIZE, args.events)
        rows = []

        for _ in range(batch_start, batch_end):
            vehicle_id = random.choice(VEHICLE_IDS)
            event = generate_telemetry_event(vehicle_id)
            rows.append(event)

        # Insert the batch
        channel.insert_rows(rows)
        total_inserted += len(rows)

        print(f"  Batch {batch_start // BATCH_SIZE + 1}: "
              f"inserted {len(rows)} rows (total: {total_inserted}/{args.events})")

        # Simulate real-time arrival
        if batch_end < args.events:
            time.sleep(BATCH_DELAY_SECONDS)

    elapsed = time.time() - start_time

    print(f"\nStreaming complete.")
    print(f"  Total rows:    {total_inserted}")
    print(f"  Elapsed time:  {elapsed:.1f}s")
    print(f"  Throughput:    {total_inserted / elapsed:.0f} rows/s")

    # Close the channel
    channel.close()
    client.close()

    print("\nChannel closed. Data will be queryable within seconds.")


if __name__ == "__main__":
    main()
