from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from app.db import get_conn
from app.schemas import LocationCreate, SensorCreate, SensorReadingCreate

app = FastAPI(title="IoT Data Logging System", description="Practical software for the Project 5 PostgreSQL time-series database", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
BASE_DIR = Path(__file__).resolve().parent
app.mount("/static", StaticFiles(directory=BASE_DIR / "static"), name="static")
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

@app.get("/", response_class=HTMLResponse)
def dashboard(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/api/locations")
def list_locations() -> list[dict[str, Any]]:
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, name, description, latitude, longitude, created_at FROM locations ORDER BY name")
        return cur.fetchall()

@app.post("/api/locations", status_code=201)
def create_location(payload: LocationCreate) -> dict[str, Any]:
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO locations (name, description, latitude, longitude) VALUES (%s, %s, %s, %s) RETURNING id, name, description, latitude, longitude, created_at",
            (payload.name, payload.description, payload.latitude, payload.longitude),
        )
        return cur.fetchone()

@app.get("/api/sensors")
def list_sensors(location_id: Optional[int] = None) -> list[dict[str, Any]]:
    sql = "SELECT s.id, s.sensor_code, s.sensor_type, s.location_id, l.name AS location_name, s.temperature_min, s.temperature_max, s.humidity_min, s.humidity_max, s.is_active, s.installed_at FROM sensors s JOIN locations l ON l.id = s.location_id"
    params: list[Any] = []
    if location_id is not None:
        sql += " WHERE s.location_id = %s"
        params.append(location_id)
    sql += " ORDER BY s.sensor_code"
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()

@app.post("/api/sensors", status_code=201)
def create_sensor(payload: SensorCreate) -> dict[str, Any]:
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("SELECT 1 FROM locations WHERE id = %s", (payload.location_id,))
        if cur.fetchone() is None:
            raise HTTPException(status_code=404, detail="Location not found")
        cur.execute(
            "INSERT INTO sensors (sensor_code, location_id, sensor_type, temperature_min, temperature_max, humidity_min, humidity_max) VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id, sensor_code, location_id, sensor_type, temperature_min, temperature_max, humidity_min, humidity_max, is_active, installed_at",
            (payload.sensor_code, payload.location_id, payload.sensor_type, payload.temperature_min, payload.temperature_max, payload.humidity_min, payload.humidity_max),
        )
        return cur.fetchone()

@app.post("/api/readings", status_code=201)
def create_sensor_reading(payload: SensorReadingCreate) -> dict[str, Any]:
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("SELECT insert_sensor_reading(%s, %s, %s, %s) AS id", (payload.sensor_code, payload.recorded_at, payload.temperature, payload.humidity))
        inserted = cur.fetchone()
        cur.execute(
            "SELECT sr.id, sr.recorded_at, sr.temperature, sr.humidity, s.sensor_code, l.name AS location_name FROM sensor_readings sr JOIN sensors s ON s.id = sr.sensor_id JOIN locations l ON l.id = s.location_id WHERE sr.id = %s ORDER BY sr.recorded_at DESC LIMIT 1",
            (inserted['id'],),
        )
        return cur.fetchone()

@app.get("/api/readings")
def list_readings(sensor_code: Optional[str] = None, start_at: Optional[datetime] = None, end_at: Optional[datetime] = None, limit: int = Query(50, ge=1, le=500)) -> list[dict[str, Any]]:
    conditions = []
    params: list[Any] = []
    sql = "SELECT sr.id, sr.recorded_at, sr.temperature, sr.humidity, s.sensor_code, l.name AS location_name FROM sensor_readings sr JOIN sensors s ON s.id = sr.sensor_id JOIN locations l ON l.id = s.location_id"
    if sensor_code:
        conditions.append("s.sensor_code = %s")
        params.append(sensor_code)
    if start_at:
        conditions.append("sr.recorded_at >= %s")
        params.append(start_at)
    if end_at:
        conditions.append("sr.recorded_at <= %s")
        params.append(end_at)
    if conditions:
        sql += " WHERE " + " AND ".join(conditions)
    sql += " ORDER BY sr.recorded_at DESC LIMIT %s"
    params.append(limit)
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()

@app.get("/api/reports/daily-averages")
def daily_averages(start_date: date = Query(default_factory=date.today), end_date: date = Query(default_factory=date.today), sensor_code: Optional[str] = None) -> list[dict[str, Any]]:
    params: list[Any] = [start_date, end_date]
    sql = "SELECT * FROM v_daily_sensor_averages WHERE reading_date BETWEEN %s AND %s"
    if sensor_code:
        sql += " AND sensor_code = %s"
        params.append(sensor_code)
    sql += " ORDER BY reading_date DESC, sensor_code"
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()

@app.get("/api/reports/anomalies")
def anomalies(start_at: Optional[datetime] = None, end_at: Optional[datetime] = None, sensor_code: Optional[str] = None) -> list[dict[str, Any]]:
    conditions = []
    params: list[Any] = []
    sql = "SELECT * FROM v_sensor_anomalies"
    if start_at:
        conditions.append("recorded_at >= %s")
        params.append(start_at)
    if end_at:
        conditions.append("recorded_at <= %s")
        params.append(end_at)
    if sensor_code:
        conditions.append("sensor_code = %s")
        params.append(sensor_code)
    if conditions:
        sql += " WHERE " + " AND ".join(conditions)
    sql += " ORDER BY recorded_at DESC"
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()

@app.get("/api/reports/summary")
def summary(start_at: Optional[datetime] = None, end_at: Optional[datetime] = None) -> dict[str, Any]:
    if start_at is None:
        start_at = datetime.now(timezone.utc) - timedelta(days=7)
    if end_at is None:
        end_at = datetime.now(timezone.utc)
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) AS total_readings, COUNT(DISTINCT sensor_id) AS active_sensors, ROUND(AVG(temperature), 2) AS avg_temperature, ROUND(AVG(humidity), 2) AS avg_humidity, MIN(recorded_at) AS first_reading_at, MAX(recorded_at) AS last_reading_at FROM sensor_readings WHERE recorded_at BETWEEN %s AND %s",
            (start_at, end_at),
        )
        headline = cur.fetchone()
        cur.execute(
            "SELECT location_name, COUNT(*) AS total_anomalies FROM v_sensor_anomalies WHERE recorded_at BETWEEN %s AND %s GROUP BY location_name ORDER BY total_anomalies DESC, location_name",
            (start_at, end_at),
        )
        anomaly_breakdown = cur.fetchall()
        cur.execute(
            "SELECT s.sensor_code, l.name AS location_name, MAX(sr.recorded_at) AS latest_reading_at, ROUND(AVG(sr.temperature), 2) AS avg_temperature, ROUND(AVG(sr.humidity), 2) AS avg_humidity, COUNT(sr.id) AS reading_count FROM sensors s JOIN locations l ON l.id = s.location_id LEFT JOIN sensor_readings sr ON sr.sensor_id = s.id AND sr.recorded_at BETWEEN %s AND %s GROUP BY s.sensor_code, l.name ORDER BY s.sensor_code",
            (start_at, end_at),
        )
        per_sensor = cur.fetchall()
        return {"window": {"start_at": start_at, "end_at": end_at}, "headline": headline, "anomaly_breakdown": anomaly_breakdown, "per_sensor": per_sensor}
