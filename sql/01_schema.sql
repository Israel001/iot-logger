CREATE TABLE IF NOT EXISTS locations (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    latitude NUMERIC(9,6),
    longitude NUMERIC(9,6),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sensors (
    id BIGSERIAL PRIMARY KEY,
    sensor_code TEXT NOT NULL UNIQUE,
    location_id BIGINT NOT NULL REFERENCES locations(id) ON DELETE RESTRICT,
    sensor_type TEXT NOT NULL DEFAULT 'environment',
    installed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    temperature_min NUMERIC(5,2) NOT NULL DEFAULT 10.00,
    temperature_max NUMERIC(5,2) NOT NULL DEFAULT 40.00,
    humidity_min NUMERIC(5,2) NOT NULL DEFAULT 20.00,
    humidity_max NUMERIC(5,2) NOT NULL DEFAULT 80.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_temperature_thresholds CHECK (temperature_min < temperature_max),
    CONSTRAINT chk_humidity_thresholds CHECK (humidity_min < humidity_max)
);

CREATE TABLE IF NOT EXISTS sensor_readings (
    id BIGSERIAL NOT NULL,
    sensor_id BIGINT NOT NULL REFERENCES sensors(id) ON DELETE CASCADE,
    recorded_at TIMESTAMPTZ NOT NULL,
    temperature NUMERIC(5,2) NOT NULL,
    humidity NUMERIC(5,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, recorded_at),
    CONSTRAINT uq_sensor_recorded UNIQUE (sensor_id, recorded_at),
    CONSTRAINT chk_temperature_range CHECK (temperature >= -50 AND temperature <= 120),
    CONSTRAINT chk_humidity_range CHECK (humidity >= 0 AND humidity <= 100)
) PARTITION BY RANGE (recorded_at);

DO $$
DECLARE
    start_month DATE := date_trunc('month', CURRENT_DATE)::date - INTERVAL '2 months';
    end_month DATE := date_trunc('month', CURRENT_DATE)::date + INTERVAL '12 months';
    current_month DATE := start_month;
    partition_name TEXT;
BEGIN
    WHILE current_month < end_month LOOP
        partition_name := 'sensor_readings_' || to_char(current_month, 'YYYY_MM');
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I PARTITION OF sensor_readings FOR VALUES FROM (%L) TO (%L);',
            partition_name,
            current_month,
            (current_month + INTERVAL '1 month')::date
        );
        current_month := (current_month + INTERVAL '1 month')::date;
    END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_sensor_readings_sensor_recorded_at
    ON sensor_readings (sensor_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_sensor_readings_recorded_at_brin
    ON sensor_readings USING BRIN (recorded_at);

CREATE OR REPLACE VIEW v_daily_sensor_averages AS
SELECT
    sr.sensor_id,
    s.sensor_code,
    l.name AS location_name,
    date_trunc('day', sr.recorded_at)::date AS reading_date,
    ROUND(AVG(sr.temperature), 2) AS avg_temperature,
    ROUND(AVG(sr.humidity), 2) AS avg_humidity,
    COUNT(*) AS reading_count
FROM sensor_readings sr
JOIN sensors s ON s.id = sr.sensor_id
JOIN locations l ON l.id = s.location_id
GROUP BY sr.sensor_id, s.sensor_code, l.name, date_trunc('day', sr.recorded_at)::date;

CREATE OR REPLACE VIEW v_sensor_anomalies AS
WITH reading_deltas AS (
    SELECT
        sr.id,
        sr.sensor_id,
        s.sensor_code,
        l.name AS location_name,
        sr.recorded_at,
        sr.temperature,
        sr.humidity,
        s.temperature_min,
        s.temperature_max,
        s.humidity_min,
        s.humidity_max,
        LAG(sr.temperature) OVER (PARTITION BY sr.sensor_id ORDER BY sr.recorded_at) AS previous_temperature,
        LAG(sr.humidity) OVER (PARTITION BY sr.sensor_id ORDER BY sr.recorded_at) AS previous_humidity
    FROM sensor_readings sr
    JOIN sensors s ON s.id = sr.sensor_id
    JOIN locations l ON l.id = s.location_id
)
SELECT
    id,
    sensor_id,
    sensor_code,
    location_name,
    recorded_at,
    temperature,
    humidity,
    CASE
        WHEN temperature < temperature_min OR temperature > temperature_max THEN 'temperature_threshold_breach'
        WHEN humidity < humidity_min OR humidity > humidity_max THEN 'humidity_threshold_breach'
        WHEN previous_temperature IS NOT NULL AND ABS(temperature - previous_temperature) >= 10 THEN 'temperature_spike'
        WHEN previous_humidity IS NOT NULL AND ABS(humidity - previous_humidity) >= 20 THEN 'humidity_spike'
        ELSE 'normal'
    END AS anomaly_type
FROM reading_deltas
WHERE temperature < temperature_min OR temperature > temperature_max
   OR humidity < humidity_min OR humidity > humidity_max
   OR (previous_temperature IS NOT NULL AND ABS(temperature - previous_temperature) >= 10)
   OR (previous_humidity IS NOT NULL AND ABS(humidity - previous_humidity) >= 20);

CREATE OR REPLACE FUNCTION insert_sensor_reading(
    p_sensor_code TEXT,
    p_recorded_at TIMESTAMPTZ,
    p_temperature NUMERIC,
    p_humidity NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_sensor_id BIGINT;
    v_new_id BIGINT;
BEGIN
    SELECT id INTO v_sensor_id FROM sensors WHERE sensor_code = p_sensor_code;
    IF v_sensor_id IS NULL THEN
        RAISE EXCEPTION 'Unknown sensor code: %', p_sensor_code;
    END IF;
    INSERT INTO sensor_readings (sensor_id, recorded_at, temperature, humidity)
    VALUES (v_sensor_id, p_recorded_at, p_temperature, p_humidity)
    RETURNING id INTO v_new_id;
    RETURN v_new_id;
END;
$$;
