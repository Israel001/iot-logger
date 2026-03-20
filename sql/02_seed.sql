INSERT INTO locations (name, description, latitude, longitude)
VALUES
    ('Greenhouse A', 'Primary greenhouse for crop monitoring', 6.524400, 3.379200),
    ('Warehouse 1', 'Storage facility for produce', 6.601800, 3.351500),
    ('Clinic Ward', 'Smart health room for patient environment monitoring', 6.455000, 3.394200)
ON CONFLICT (name) DO NOTHING;

INSERT INTO sensors (sensor_code, location_id, sensor_type, temperature_min, temperature_max, humidity_min, humidity_max)
SELECT 'GH-A-001', id, 'environment', 18, 35, 40, 85 FROM locations WHERE name = 'Greenhouse A'
ON CONFLICT (sensor_code) DO NOTHING;
INSERT INTO sensors (sensor_code, location_id, sensor_type, temperature_min, temperature_max, humidity_min, humidity_max)
SELECT 'WH-001', id, 'environment', 10, 30, 30, 70 FROM locations WHERE name = 'Warehouse 1'
ON CONFLICT (sensor_code) DO NOTHING;
INSERT INTO sensors (sensor_code, location_id, sensor_type, temperature_min, temperature_max, humidity_min, humidity_max)
SELECT 'CL-001', id, 'environment', 20, 28, 35, 60 FROM locations WHERE name = 'Clinic Ward'
ON CONFLICT (sensor_code) DO NOTHING;

WITH sensor_ids AS (
    SELECT sensor_code, id FROM sensors WHERE sensor_code IN ('GH-A-001', 'WH-001', 'CL-001')
), generated AS (
    SELECT
        s.id AS sensor_id,
        s.sensor_code,
        gs AS recorded_at,
        CASE
            WHEN s.sensor_code = 'GH-A-001' THEN 24 + (RANDOM() * 6)
            WHEN s.sensor_code = 'WH-001' THEN 20 + (RANDOM() * 4)
            ELSE 22 + (RANDOM() * 3)
        END AS temperature,
        CASE
            WHEN s.sensor_code = 'GH-A-001' THEN 55 + (RANDOM() * 20)
            WHEN s.sensor_code = 'WH-001' THEN 45 + (RANDOM() * 10)
            ELSE 40 + (RANDOM() * 10)
        END AS humidity
    FROM sensor_ids s
    CROSS JOIN generate_series(
        date_trunc('hour', NOW() - INTERVAL '3 days'),
        date_trunc('hour', NOW()),
        INTERVAL '1 hour'
    ) gs
)
INSERT INTO sensor_readings (sensor_id, recorded_at, temperature, humidity)
SELECT sensor_id, recorded_at, ROUND(temperature::numeric, 2), ROUND(humidity::numeric, 2)
FROM generated
ON CONFLICT (sensor_id, recorded_at) DO NOTHING;

SELECT insert_sensor_reading('GH-A-001', NOW() - INTERVAL '90 minutes', 44.00, 90.00)
WHERE NOT EXISTS (
    SELECT 1 FROM sensor_readings sr
    JOIN sensors s ON s.id = sr.sensor_id
    WHERE s.sensor_code = 'GH-A-001' AND sr.recorded_at = NOW() - INTERVAL '90 minutes'
);
SELECT insert_sensor_reading('CL-001', NOW() - INTERVAL '45 minutes', 12.00, 22.00)
WHERE NOT EXISTS (
    SELECT 1 FROM sensor_readings sr
    JOIN sensors s ON s.id = sr.sensor_id
    WHERE s.sensor_code = 'CL-001' AND sr.recorded_at = NOW() - INTERVAL '45 minutes'
);
