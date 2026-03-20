# IoT Data Logging System

A practical software implementation of Project 5: IoT-Based Data Logging Database.

## Understand this project

This repository shows the software side of an IoT data logging system in beginner-friendly form. It stores sensor readings, analyzes them for anomalies, exposes them through APIs, and displays them in a dashboard, but it does not include physical sensor hardware, device firmware, a gateway, or a message broker.

If you want a plain-English walkthrough of every component and how the pieces connect, read [docs/project-explainer.md](/Users/i.obanijesu/Downloads/iot_logger_app/docs/project-explainer.md).

## What it does
- stores sensor readings with timestamp, temperature, humidity, and location
- uses a PostgreSQL time-series schema optimized with partitioning and indexes
- exposes REST APIs for locations, sensors, readings, daily averages, anomaly detection, and reporting summaries
- provides a simple browser dashboard for demo purposes

## Stack
- PostgreSQL 16
- FastAPI
- Psycopg 3
- Docker Compose

## Setup
1. Copy `.env.example` to `.env`.
2. Put your real PostgreSQL credentials in `.env`.
3. If your password contains characters like `$`, wrap the value in quotes in `.env`.
4. Run `docker compose up --build`; the stack will initialize the external database automatically.

## Run
```bash
docker compose up --build
```

On startup, the `init-db` service connects to your external PostgreSQL database, applies the schema, and seeds demo data only if the database is still empty.

To force a fresh reseed later, run:
```bash
docker compose --profile tools run --rm seed-db
```

That command truncates the demo tables and reloads `sql/02_seed.sql`.

Open:
- Dashboard: `http://localhost:8002`
- API docs: `http://localhost:8002/docs`

## Example API calls
```bash
curl -X POST http://localhost:8002/api/readings   -H "Content-Type: application/json"   -d '{"sensor_code":"GH-A-001","recorded_at":"2026-03-18T12:30:00Z","temperature":31.4,"humidity":67.5}'
```

```bash
curl "http://localhost:8002/api/reports/anomalies"
```

```bash
curl "http://localhost:8002/api/reports/daily-averages?start_date=2026-03-18&end_date=2026-03-18"
```

## Design notes
- `sensor_readings` is partitioned by month on `recorded_at`
- `BRIN(recorded_at)` speeds up large date-range scans
- `(sensor_id, recorded_at DESC)` supports per-sensor history lookups
- anomaly detection flags threshold breaches and abrupt spikes
