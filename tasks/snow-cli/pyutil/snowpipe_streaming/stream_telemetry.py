#!/usr/bin/env python3
"""Streaming telemetry simulator for the shirc Iceberg V3 demo.

What it does
------------
Simulates a fleet of vehicles emitting telemetry (GPS, engine metrics,
diagnostic codes, driver-behavior counters) and inserts each event as a
VARIANT payload into the Iceberg V3 table
``<DEMO_DATABASE_NAME>.<DEMO_SCHEMA_NAME_BRONZE>.VEHICLE_TELEMETRY_STREAM``.

Why a simulator
---------------
A real fleet would publish telemetry to an MQTT/IoT broker (AWS IoT Core,
Azure IoT Hub, HiveMQ, EMQX, ...). To keep the demo self-contained we
generate the events locally and ship them straight to Snowflake. The
``send_external_lineage`` helper still posts an OpenLineage event so
Snowsight's Lineage view shows the (fictional) broker as an upstream node.

How it's invoked
----------------
This script is normally launched by go-task::

    task stream-telemetry              # streams ~600 events (5-min cap)
    task stream-telemetry EVENT_COUNT=100   # exits after 100 events

Task exports ``.env/iceberg.env`` into the subprocess, so all
``DEMO_*`` and ``CLI_CONNECTION_NAME`` variables are available via
``os.getenv``. The ``--events N`` CLI flag (added by ``main()``) overrides
the default duration-based stop condition.

Connection
----------
Authentication piggy-backs on the named ``snow`` CLI connection
identified by ``CLI_CONNECTION_NAME``. ``_load_named_connection()`` reads
either ``~/.snowflake/connections.toml`` or ``[connections.<name>]`` in
``~/.snowflake/config.toml`` and normalizes the snow-CLI alias
``private_key_path`` to ``private_key_file`` so keypair auth works
out-of-the-box regardless of which alias the user picked.
"""

import argparse
import json
import os
import random
import signal
import sys
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import requests

# ---------------------------------------------------------------------------
# Snowflake SDKs
#
# - snowflake.ingest.streaming (snowpipe-streaming): the data path. We open
#   a channel against the default pipe ``VEHICLE_TELEMETRY_STREAM-STREAMING``
#   and call ``append_rows()`` for each batch. No warehouse needed; the
#   ingestion engine writes Parquet + Iceberg metadata directly to the
#   table's storage location.
# ---------------------------------------------------------------------------
try:
    from snowflake.ingest.streaming import StreamingIngestClient

    STREAMING_AVAILABLE = True
except ImportError:
    STREAMING_AVAILABLE = False
    print("ERROR: snowpipe-streaming is not installed. Run: pip install snowpipe-streaming")

# ---------------------------------------------------------------------------
# Configuration
#
# Everything below is read from the environment that go-task already
# populated from .env/iceberg.env. Required vars are validated with a hard
# exit; everything else falls back to sensible defaults so the script can
# also be invoked manually for ad-hoc testing.
# ---------------------------------------------------------------------------

# --- Target object identity (medallion: BRONZE / RAW) ----------------------
CLI_CONNECTION_NAME = os.getenv('CLI_CONNECTION_NAME')
SNOWFLAKE_DATABASE = os.getenv('DEMO_DATABASE_NAME', 'FLEET_ANALYTICS_DB')
SNOWFLAKE_SCHEMA = os.getenv('DEMO_SCHEMA_NAME_BRONZE', 'RAW')
SNOWFLAKE_TABLE = 'VEHICLE_TELEMETRY_STREAM'  # created by 001-create_iceberg_tables.sql
SNOWFLAKE_WAREHOUSE = os.getenv('DEMO_WAREHOUSE_NAME', 'FLEET_ANALYTICS_WH')

if not CLI_CONNECTION_NAME:
    # Hard failure: without a connection name we can't authenticate.
    print("ERROR: CLI_CONNECTION_NAME is not set in .env/iceberg.env")
    sys.exit(1)

# --- Workload shape --------------------------------------------------------
# MAX_DURATION_SECONDS is a wall-clock cap. When --events is also passed
# (see main()), whichever bound trips first stops the loop.
MAX_DURATION_SECONDS = int(os.getenv('STREAMING_DURATION', 300))   # 5 minutes
VEHICLE_COUNT = int(os.getenv('STREAMING_VEHICLE_COUNT', 50))      # fleet size
EVENTS_PER_SECOND = float(os.getenv('STREAMING_EVENTS_PER_SECOND', 2))
BATCH_SIZE = 10  # events accumulated locally before each commit

# --- External lineage (OpenLineage POST to Snowflake REST API) -------------
# These describe a *fictional* upstream IoT/MQTT broker. The lineage POST
# tells Snowflake "this table is downstream of <broker>" so Snowsight's
# Lineage tab shows a meaningful upstream node even though no real broker
# exists. See: https://docs.snowflake.com/en/user-guide/external-lineage
IOT_BROKER_NAMESPACE = os.getenv('IOT_BROKER_NAMESPACE', 'mqtt://fleet-iot-gateway.example.com')
IOT_SOURCE_NAME = os.getenv('IOT_SOURCE_NAME', 'Fleet Vehicle Telematics')
IOT_TOPIC_PATTERN = os.getenv('IOT_TOPIC_PATTERN', 'fleet/vehicles/+/telemetry')
ENABLE_EXTERNAL_LINEAGE = os.getenv('ENABLE_EXTERNAL_LINEAGE', 'true').lower() == 'true'

# Account URL host for the REST endpoint. When unset we resolve it from
# the account identifier in the named CLI connection.
SNOWFLAKE_ACCOUNT_URL = os.getenv('SNOWFLAKE_ACCOUNT_URL')

# --- Process-wide signal handling ------------------------------------------
# Flipped to False by Ctrl-C / SIGTERM so the streaming loop exits cleanly,
# flushing any in-flight batch and posting lineage before disconnecting.
running = True


def signal_handler(sig, frame):
    """Flip the global ``running`` flag so the main loop exits gracefully."""
    global running
    print("\n\nReceived interrupt signal. Shutting down gracefully...")
    running = False


signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


def _generate_jwt() -> str:
    """Generate a JWT using the Snow CLI for the active connection.

    Shells out to ``snow connection generate-jwt --connection <name> --silent``
    which signs a keypair JWT using the private key already configured in the
    named connection. The token is valid for ~60 minutes.

    Returns the raw JWT string. Raises ``RuntimeError`` on failure.
    """
    import subprocess

    cmd = ["snow", "connection", "generate-jwt", "--connection", CLI_CONNECTION_NAME, "--silent"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    except FileNotFoundError:
        raise RuntimeError(
            "Cannot generate JWT: 'snow' CLI not found on PATH. "
            "Install with: pip install snowflake-cli"
        )
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"snow connection generate-jwt failed: {e.stderr.strip()}")

    jwt = result.stdout.strip()
    if not jwt:
        raise RuntimeError("snow connection generate-jwt returned empty output")
    return jwt


def send_external_lineage(account: str, total_events: int, start_time: datetime, end_time: datetime):
    """POST an OpenLineage COMPLETE event to Snowflake's External Lineage endpoint.

    Establishes a directed lineage edge:

        IoT/MQTT broker (input)  --->  RAW.VEHICLE_TELEMETRY_STREAM (output)

    so the Lineage tab in Snowsight shows `IOT_SOURCE_NAME` as an upstream
    producer even though, in this demo, the events were synthesized locally.

    Authentication uses a JWT generated by ``snow connection generate-jwt``,
    which reuses the keypair auth from the named CLI connection.

    Required privileges (run once as ACCOUNTADMIN)::

        GRANT INGEST LINEAGE ON ACCOUNT TO ROLE <streaming-role>;

    Failure modes:
      - ``not ENABLE_EXTERNAL_LINEAGE`` -> silent skip.
      - JWT generation fails -> printed but non-fatal.
      - HTTP 403 -> grant ``INGEST LINEAGE`` and retry.
      - Other HTTP/network errors -> printed but non-fatal; the streaming
        run is considered successful regardless.

    See: https://docs.snowflake.com/en/user-guide/external-lineage
    """
    if not ENABLE_EXTERNAL_LINEAGE:
        return

    # Generate a fresh JWT from the Snow CLI connection.
    try:
        jwt = _generate_jwt()
    except RuntimeError as e:
        print(f"\nNote: Skipping lineage registration: {e}")
        return

    # Build lineage endpoint. The REST hostname requires dashes (not
    # underscores) — SSL certs are only issued for the dashed form.
    account_url = (SNOWFLAKE_ACCOUNT_URL or account).lower().replace("_", "-")
    lineage_endpoint = f"https://{account_url}.snowflakecomputing.com/api/v2/lineage/external-lineage"

    # OpenLineage COMPLETE event -- one input dataset (the broker topic), one
    # output dataset (the Iceberg table). The facets carry human-readable
    # descriptions plus row/byte stats so Snowsight can display them.
    lineage_event = {
        "eventType": "COMPLETE",
        "eventTime": end_time.isoformat(),
        "job": {
            "namespace": "snowflake-streaming",
            "name": "fleet-telemetry-ingest"
        },
        "run": {
            "runId": str(uuid.uuid4()),
            "facets": {
                "processing_engine": {
                    "_producer": "https://github.com/snowflakedb/snowpipe-streaming",
                    "_schemaURL": "https://openlineage.io/spec/facets/1-0-0/ProcessingEngineRunFacet.json",
                    "name": "Snowpipe Streaming Python SDK",
                    "version": "1.0"
                }
            }
        },
        "producer": "https://github.com/snowflakedb/snowpipe-streaming",
        "schemaURL": "https://openlineage.io/spec/1-0-5/OpenLineage.json",
        "inputs": [
            {
                # Upstream node (fictional MQTT/IoT broker)
                "namespace": IOT_BROKER_NAMESPACE,
                "name": IOT_SOURCE_NAME,
                "facets": {
                    "datasetType": {
                        "datasetType": "IoT Telemetry Stream"
                    },
                    "documentation": {
                        "_producer": "https://github.com/snowflakedb/snowpipe-streaming",
                        "_schemaURL": "https://openlineage.io/spec/facets/1-0-0/DocumentationDatasetFacet.json",
                        "description": f"Vehicle telemetry from MQTT topic: {IOT_TOPIC_PATTERN}. Vehicles publish GPS, engine metrics, and driver behavior data via cellular telematics units."
                    },
                    "dataSource": {
                        "_producer": "https://github.com/snowflakedb/snowpipe-streaming",
                        "_schemaURL": "https://openlineage.io/spec/facets/1-0-0/DataSourceDatasetFacet.json",
                        "name": IOT_SOURCE_NAME,
                        "uri": f"{IOT_BROKER_NAMESPACE}/{IOT_TOPIC_PATTERN}"
                    }
                }
            }
        ],
        "outputs": [
            {
                # Downstream node (the actual Iceberg table). Namespace must
                # be ``snowflake://<account>`` for Snowsight to resolve it.
                "namespace": f"snowflake://{account}",
                "name": f"{SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}.{SNOWFLAKE_TABLE}",
                "facets": {
                    "datasetType": {
                        "datasetType": "ICEBERG TABLE"
                    },
                    "outputStatistics": {
                        "_producer": "https://github.com/snowflakedb/snowpipe-streaming",
                        "_schemaURL": "https://openlineage.io/spec/facets/1-0-0/OutputStatisticsOutputDatasetFacet.json",
                        "rowCount": total_events,
                        "size": total_events * 500  # rough mean payload bytes
                    }
                }
            }
        ]
    }

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {jwt}",
        "Accept": "application/json",
        "User-Agent": "FleetTelemetryStreamer/1.0",
        "X-Snowflake-Authorization-Token-Type": "KEYPAIR_JWT"
    }

    try:
        response = requests.post(
            lineage_endpoint,
            headers=headers,
            json=lineage_event,
            timeout=30
        )

        if response.status_code in (200, 201, 202):
            print(
                f"\n✓ External lineage registered: {IOT_SOURCE_NAME} → {SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}.{SNOWFLAKE_TABLE}")
            print("  View in Snowsight: Catalog » Database Explorer » Select table » Lineage tab")
        elif response.status_code == 403:
            # Most common failure: privilege missing. Print the exact GRANT.
            print(f"\nNote: External lineage not registered (missing INGEST LINEAGE privilege)")
            print("  To enable, run as ACCOUNTADMIN:")
            print("    GRANT INGEST LINEAGE ON ACCOUNT TO ROLE ACCOUNTADMIN;")
        else:
            print(f"\nNote: Lineage registration returned status {response.status_code}: {response.text[:200]}")

    except requests.exceptions.RequestException as e:
        # Network / DNS / TLS issues -- log but don't fail the streaming run.
        print(f"\nNote: Could not send lineage event: {e}")


# ===========================================================================
# Vehicle simulation
#
# Each vehicle is a small mutable state machine. The loop in main() picks a
# random subset of vehicles per tick, walks each one through one step of
# physics-ish updates, and emits a JSON event for it. The state object
# carries cumulative driver-behavior counters (hard accelerations, brakes,
# sharp turns) so downstream Iceberg dynamic tables can aggregate them.
# ===========================================================================


@dataclass
class VehicleState:
    """Mutable state for one simulated vehicle.

    Counters (``hard_accelerations``, ``hard_brakes``, ``sharp_turns``)
    accumulate across the run and are included in every emitted event.
    """
    vehicle_id: str
    latitude: float
    longitude: float
    speed_mph: float
    heading: float
    engine_rpm: int
    engine_temp_f: int
    oil_pressure_psi: float
    fuel_level_pct: float
    check_engine: bool
    tire_pressure_warning: bool
    hard_accelerations: int
    hard_brakes: int
    sharp_turns: int
    region: str


def create_vehicle_fleet(count: int) -> list[VehicleState]:
    """Build ``count`` vehicles distributed across five US regions.

    Vehicles are seeded with random-but-plausible positions, speeds, and
    engine readings. About 5% start with a check-engine light on, ~3% with
    a tire-pressure warning, simulating a real fleet's baseline issue rate.
    """
    regions = [
        ("Pacific Northwest", 47.6, -122.3),
        ("California", 34.0, -118.2),
        ("Mountain West", 39.7, -104.9),
        ("Midwest", 41.8, -87.6),
        ("Northeast", 40.7, -74.0),
    ]

    vehicles = []
    for i in range(count):
        # Round-robin across regions; jitter lat/lon to spread within region.
        region_name, base_lat, base_lon = regions[i % len(regions)]
        vehicle = VehicleState(
            vehicle_id=f"VH-{i:04d}",
            latitude=base_lat + random.uniform(-0.5, 0.5),
            longitude=base_lon + random.uniform(-0.5, 0.5),
            speed_mph=random.uniform(0, 65),
            heading=random.uniform(0, 360),
            engine_rpm=random.randint(800, 3500),
            engine_temp_f=random.randint(180, 210),
            oil_pressure_psi=random.uniform(30, 50),
            fuel_level_pct=random.uniform(20, 100),
            check_engine=random.random() < 0.05,
            tire_pressure_warning=random.random() < 0.03,
            hard_accelerations=0,
            hard_brakes=0,
            sharp_turns=0,
            region=region_name
        )
        vehicles.append(vehicle)

    return vehicles


def update_vehicle_state(vehicle: VehicleState) -> VehicleState:
    """Advance a vehicle's state by one simulation tick.

    Mutates and returns the same object (returning is a convenience for
    chained expressions). Models speed drift, simplified position update,
    occasional turns, engine metric drift, fuel burn, and rare diagnostic
    events. Hard accel/brake counters increment when the speed delta
    exceeds a threshold.
    """
    # Speed: small random walk, clamped to a plausible 0-95 mph range.
    speed_change = random.uniform(-10, 10)
    vehicle.speed_mph = max(0, min(95, vehicle.speed_mph + speed_change))

    # Position: stretch lat/lon proportional to speed. Not realistic motion,
    # just enough to make consecutive points form a plausible scatter.
    movement = vehicle.speed_mph * 0.00001
    vehicle.latitude += movement * random.uniform(-0.5, 1)
    vehicle.longitude += movement * random.uniform(-1, 0.5)

    # Heading: 10% chance of a turn each tick; >30° turns count as "sharp".
    if random.random() < 0.1:
        heading_change = random.uniform(-45, 45)
        vehicle.heading = (vehicle.heading + heading_change) % 360
        if abs(heading_change) > 30:
            vehicle.sharp_turns += 1

    # Engine metrics drift within physically plausible ranges.
    vehicle.engine_rpm = max(600, min(6000, vehicle.engine_rpm + random.randint(-300, 300)))
    vehicle.engine_temp_f = max(160, min(250, vehicle.engine_temp_f + random.randint(-3, 5)))
    vehicle.oil_pressure_psi = max(20, min(60, vehicle.oil_pressure_psi + random.uniform(-2, 2)))

    # Fuel: linear-ish burn rate proportional to speed.
    fuel_consumption = vehicle.speed_mph * 0.001 + random.uniform(0, 0.01)
    vehicle.fuel_level_pct = max(0, vehicle.fuel_level_pct - fuel_consumption)

    # Driver behavior: a sudden speed change is an aggressive event.
    if abs(speed_change) > 8:
        if speed_change > 0:
            vehicle.hard_accelerations += 1
        else:
            vehicle.hard_brakes += 1

    # Rare diagnostic flips, simulating a CEL or TPMS warning toggling.
    if random.random() < 0.001:
        vehicle.check_engine = not vehicle.check_engine
    if random.random() < 0.002:
        vehicle.tire_pressure_warning = not vehicle.tire_pressure_warning

    return vehicle


def generate_telemetry_event(vehicle: VehicleState) -> dict:
    """Build the wire-format event for one vehicle tick.

    Returns a dict with three keys matching the columns of
    ``VEHICLE_TELEMETRY_STREAM``:

      - ``VEHICLE_ID``       (STRING)
      - ``EVENT_TIMESTAMP``  (TIMESTAMP_NTZ -- pass a datetime object)
      - ``TELEMETRY_DATA``   (VARIANT -- pass a native dict, NOT a JSON
                              string. The SDK serializes dicts to OBJECT;
                              passing a JSON string would land as VARCHAR.)

    The nested JSON shape under ``TELEMETRY_DATA`` is what downstream
    dynamic tables (TELEMETRY_ENRICHED, DAILY_FLEET_SUMMARY) extract via
    colon notation.
    """
    now = datetime.now(timezone.utc)

    # Native dict -- the streaming SDK serializes this directly to VARIANT.
    telemetry_data = {
        "location": {
            "lat": round(vehicle.latitude, 6),
            "lon": round(vehicle.longitude, 6)
        },
        "speed_mph": round(vehicle.speed_mph, 1),
        "heading": round(vehicle.heading, 1),
        "engine": {
            "rpm": vehicle.engine_rpm,
            "temperature_f": vehicle.engine_temp_f,
            "oil_pressure_psi": round(vehicle.oil_pressure_psi, 1),
            "fuel_level_pct": round(vehicle.fuel_level_pct, 1)
        },
        "diagnostics": {
            "check_engine": vehicle.check_engine,
            "tire_pressure_warning": vehicle.tire_pressure_warning,
            # P0300 = generic random/multiple cylinder misfire (just illustrative)
            "codes": ["P0300"] if vehicle.check_engine else []
        },
        "driver_behavior": {
            "hard_acceleration_count": vehicle.hard_accelerations,
            "hard_brake_count": vehicle.hard_brakes,
            "sharp_turn_count": vehicle.sharp_turns
        },
        "metadata": {
            "region": vehicle.region,
            "timestamp_utc": now.isoformat(),
            "firmware_version": "2.4.1"
        }
    }

    return {
        # The SDK matches dict keys against the table's columns (case-insensitive).
        "VEHICLE_ID": vehicle.vehicle_id,
        "EVENT_TIMESTAMP": now,           # datetime -> TIMESTAMP_NTZ
        "TELEMETRY_DATA": telemetry_data, # native dict -> VARIANT (OBJECT)
    }


# ===========================================================================
# Streaming client management
#
# We resolve credentials from snow CLI's TOML so users don't have to
# duplicate config across `snow connection add` and a separate streaming
# profile. The Streaming SDK requires a profile.json file containing the
# account, user, URL, and an inline PEM private key. We synthesize that
# file from the parsed connection params.
#
# The TOML parsing also normalizes snow-CLI-only aliases (eg. the
# `private_key_path` -> `private_key_file` rename) before use.
# ===========================================================================


def _load_named_connection(name: str) -> dict:
    """Return a kwargs dict mirroring the named ``snow`` CLI connection.

    Search order:
      1. ``~/.snowflake/connections.toml``  (each connection is a top-level
         table named after the connection)
      2. ``~/.snowflake/config.toml``       (each connection is under
         ``[connections.<name>]``)

    Raises ``RuntimeError`` if neither file contains the named connection.

    Aliases normalized:
      - ``private_key_path`` -> ``private_key_file``  (snow CLI <-> connector)
    """
    try:
        import tomllib  # Python 3.11+ stdlib
    except ModuleNotFoundError:
        import tomli as tomllib  # type: ignore[no-redef]

    home = Path.home() / ".snowflake"
    candidates = [home / "connections.toml", home / "config.toml"]

    for path in candidates:
        if not path.exists():
            continue
        with path.open("rb") as fh:
            data = tomllib.load(fh)

        # Layout 1 (connections.toml): [<name>]  <-- top-level table
        if name in data and isinstance(data[name], dict):
            params = dict(data[name])
            break

        # Layout 2 (config.toml): [connections.<name>]
        connections = data.get("connections", {})
        if name in connections:
            params = dict(connections[name])
            break
    else:
        raise RuntimeError(
            f"Connection '{name}' not found in {candidates[0]} or {candidates[1]}"
        )

    if "private_key_path" in params and "private_key_file" not in params:
        params["private_key_file"] = params.pop("private_key_path")

    return params


def create_streaming_client():
    """Open a Snowpipe Streaming SDK client and one channel.

    Returns ``(client, channel, account)``:
      - ``client``: a :class:`StreamingIngestClient` bound to the default
        pipe ``<table>-STREAMING`` (Snowflake auto-creates it if absent).
      - ``channel``: a single channel named ``fleet_p0`` -- production
        deployments would open multiple channels (one per partition) for
        higher throughput; one channel is plenty for the demo.
      - ``account``: the account identifier extracted from the named
        connection. Returned separately so ``send_external_lineage()`` can
        post the OpenLineage event without needing a connector connection.

    Auth requirement: the named CLI connection must use keypair auth
    (``authenticator = "SNOWFLAKE_JWT"``) -- the Streaming SDK does not
    support password auth.
    """
    if not STREAMING_AVAILABLE:
        print("ERROR: snowpipe-streaming package missing. Run: pip install snowpipe-streaming")
        sys.exit(1)

    print(f"Resolving CLI connection '{CLI_CONNECTION_NAME}'...")
    params = _load_named_connection(CLI_CONNECTION_NAME)

    if not params.get("private_key_file"):
        print(
            f"ERROR: connection '{CLI_CONNECTION_NAME}' has no private_key_file. "
            "Snowpipe Streaming requires keypair auth."
        )
        sys.exit(1)

    # SDK profile expects an inline PEM key, not a file path.
    private_key_pem = Path(params["private_key_file"]).read_text()
    profile = {
        "account": params["account"],
        "user": params["user"],
        "url": f"https://{params['account']}.snowflakecomputing.com:443",
        "private_key": private_key_pem,
    }

    # Persist a temp profile.json the SDK will read. Re-creating it each
    # run is fine -- the SDK reads it once on client construction.
    profile_path = Path("/tmp") / "shirc_streaming_profile.json"
    profile_path.write_text(json.dumps(profile))

    pipe_name = f"{SNOWFLAKE_TABLE}-STREAMING"
    print(
        f"Opening streaming client: pipe={SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}.{pipe_name}"
    )
    client = StreamingIngestClient(
        client_name="shirc_fleet_telemetry_client",
        db_name=SNOWFLAKE_DATABASE,
        schema_name=SNOWFLAKE_SCHEMA,
        pipe_name=pipe_name,
        profile_json=str(profile_path),
    )

    channel, _status = client.open_channel(channel_name="fleet_p0")
    print("Streaming channel ready.")
    return client, channel, params["account"]


def main():
    """Entry point — print a banner, open a streaming channel, run the loop.

    The loop accumulates ``BATCH_SIZE`` events locally then calls
    ``channel.append_rows()`` -- the SDK handles batching, durability, and
    background flush. It exits on the first of:
      - SIGINT/SIGTERM (handled by ``signal_handler``)
      - ``--events`` target reached
      - ``MAX_DURATION_SECONDS`` wall-clock limit elapsed
      - exception in the inner try (logged, but loop continues retrying)

    After the loop we ``wait_for_flush()`` so all queued rows commit to the
    Iceberg table before posting lineage and printing the summary.
    """
    global running

    parser = argparse.ArgumentParser(description="Stream simulated vehicle telemetry into Snowflake.")
    parser.add_argument(
        "--events",
        type=int,
        default=None,
        help="Stop after this many events. When set, overrides STREAMING_DURATION (which becomes a wall-clock cap).",
    )
    args = parser.parse_args()
    target_events = args.events

    # --- Banner ------------------------------------------------------------
    print("=" * 60)
    print("Snowflake Iceberg V3 - Streaming Telemetry Simulator")
    print("=" * 60)
    print(f"Connection: {CLI_CONNECTION_NAME}")
    print(f"Database: {SNOWFLAKE_DATABASE}")
    print(f"Table: {SNOWFLAKE_SCHEMA}.{SNOWFLAKE_TABLE}")
    print(f"Pipe: {SNOWFLAKE_TABLE}-STREAMING (Snowpipe Streaming SDK)")
    print(f"Vehicles: {VEHICLE_COUNT}")
    print(f"Events/second: {EVENTS_PER_SECOND}")
    if target_events is not None:
        print(f"Target events: {target_events}")
    print(f"Max duration: {MAX_DURATION_SECONDS} seconds")
    print("-" * 60)
    print("Press Ctrl+C to stop streaming")
    print("-" * 60)

    # --- Setup -------------------------------------------------------------
    # One client + one channel reused across all batches.
    client, channel, account = create_streaming_client()

    print(f"\nInitializing {VEHICLE_COUNT} vehicles...")
    vehicles = create_vehicle_fleet(VEHICLE_COUNT)
    print("Fleet initialized!")

    start_time = time.time()
    total_events = 0
    batch = []

    print("\nStarting streaming...\n")

    # --- Main loop ---------------------------------------------------------
    try:
        while running and (time.time() - start_time) < MAX_DURATION_SECONDS:
            # Honor --events target if set; this is in addition to (and
            # usually fires before) the wall-clock cap above.
            if target_events is not None and total_events >= target_events:
                break

            # Pick a random subset of vehicles for this tick. min() guards
            # against BATCH_SIZE > fleet size (e.g. for a tiny smoke test).
            selected_vehicles = random.sample(vehicles, min(BATCH_SIZE, len(vehicles)))

            for vehicle in selected_vehicles:
                vehicle = update_vehicle_state(vehicle)
                event = generate_telemetry_event(vehicle)
                batch.append(event)

            # Flush the batch when full. ``append_rows`` queues events for
            # async ingest; the SDK batches and writes Parquet+Iceberg
            # metadata in the background. ``offset_token`` enables
            # exactly-once recovery if the channel is reopened later.
            if len(batch) >= BATCH_SIZE:
                try:
                    next_offset = total_events + len(batch)
                    channel.append_rows(batch, end_offset_token=str(next_offset))
                    total_events = next_offset

                    # Single-line progress display (carriage-return overwrites).
                    elapsed = time.time() - start_time
                    rate = total_events / elapsed if elapsed > 0 else 0
                    print(f"\rEvents queued: {total_events:,} | "
                          f"Rate: {rate:.1f}/sec | "
                          f"Elapsed: {elapsed:.0f}s", end="", flush=True)

                    batch = []
                except Exception as e:
                    print(f"\nError appending batch: {e}")
                    # Intentionally keep the (failed) batch around so the
                    # next iteration retries it implicitly via length check.

            # Throttle the producer so we don't overshoot EVENTS_PER_SECOND.
            time.sleep(1 / EVENTS_PER_SECOND)

    except KeyboardInterrupt:
        # SIGINT also flips `running` via signal_handler, but catch here
        # too so an interrupt before the handler runs doesn't show a stack.
        pass

    # --- Flush + lineage + cleanup -----------------------------------------
    # Force any in-flight batch through, then block until all queued rows
    # commit to the Iceberg table. Without this the script may exit before
    # the SDK's background flush thread completes.
    print("\nFlushing channel...")
    try:
        channel.wait_for_flush(timeout_seconds=30)
    except Exception as e:
        print(f"Warning: flush timed out or errored: {e}")

    # Compute a [start, end] window for the OpenLineage event so Snowsight
    # can show how long the pipeline ran.
    stream_end_time = datetime.now(timezone.utc)
    stream_start_time = datetime.fromtimestamp(start_time, tz=timezone.utc)

    # Skip lineage if nothing got through — an empty event would be noise.
    if total_events > 0:
        send_external_lineage(account, total_events, stream_start_time, stream_end_time)

    try:
        channel.close()
    except Exception:
        pass
    client.close()

    # --- Final stats -------------------------------------------------------
    elapsed = time.time() - start_time
    print(f"\n\n{'=' * 60}")
    print("Streaming Complete!")
    print(f"{'=' * 60}")
    print(f"Total events streamed: {total_events:,}")
    print(f"Total time: {elapsed:.1f} seconds")
    if elapsed > 0:
        print(f"Average rate: {total_events / elapsed:.1f} events/second")
    print(f"\nQuery your data:")
    print(f"  SELECT * FROM {SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}.{SNOWFLAKE_TABLE} LIMIT 10;")
    print(f"\nView lineage in Snowsight:")
    print(
        f"  Catalog » Database Explorer » {SNOWFLAKE_DATABASE} » {SNOWFLAKE_SCHEMA} » {SNOWFLAKE_TABLE} » Lineage tab")


if __name__ == "__main__":
    main()