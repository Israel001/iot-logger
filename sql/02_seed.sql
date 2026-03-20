INSERT INTO locations (name, description, latitude, longitude)
VALUES
    ('Lagos Produce Hub', 'Fresh produce collection and monitoring point in Lagos', 6.524400, 3.379200),
    ('Kano Storage Depot', 'Storage and environmental monitoring point in Kano', 12.002200, 8.592000),
    ('Enugu Health Centre', 'Environmental monitoring point for a health facility in Enugu', 6.455000, 7.510600)
ON CONFLICT (name) DO NOTHING;

INSERT INTO sensors (sensor_code, location_id, sensor_type, temperature_min, temperature_max, humidity_min, humidity_max)
SELECT 'LAG-ENV-001', id, 'environment', 18, 35, 40, 85 FROM locations WHERE name = 'Lagos Produce Hub'
ON CONFLICT (sensor_code) DO NOTHING;
INSERT INTO sensors (sensor_code, location_id, sensor_type, temperature_min, temperature_max, humidity_min, humidity_max)
SELECT 'KAN-ENV-001', id, 'environment', 10, 30, 30, 70 FROM locations WHERE name = 'Kano Storage Depot'
ON CONFLICT (sensor_code) DO NOTHING;
INSERT INTO sensors (sensor_code, location_id, sensor_type, temperature_min, temperature_max, humidity_min, humidity_max)
SELECT 'ENU-ENV-001', id, 'environment', 20, 28, 35, 60 FROM locations WHERE name = 'Enugu Health Centre'
ON CONFLICT (sensor_code) DO NOTHING;

WITH sensor_ids AS (
    SELECT sensor_code, id FROM sensors WHERE sensor_code IN ('LAG-ENV-001', 'KAN-ENV-001', 'ENU-ENV-001')
), generated AS (
    SELECT
        s.id AS sensor_id,
        s.sensor_code,
        gs AS recorded_at,
        CASE
            WHEN s.sensor_code = 'LAG-ENV-001' THEN 24 + (RANDOM() * 6)
            WHEN s.sensor_code = 'KAN-ENV-001' THEN 20 + (RANDOM() * 4)
            ELSE 22 + (RANDOM() * 3)
        END AS temperature,
        CASE
            WHEN s.sensor_code = 'LAG-ENV-001' THEN 55 + (RANDOM() * 20)
            WHEN s.sensor_code = 'KAN-ENV-001' THEN 45 + (RANDOM() * 10)
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

SELECT insert_sensor_reading('LAG-ENV-001', NOW() - INTERVAL '90 minutes', 44.00, 90.00)
WHERE NOT EXISTS (
    SELECT 1 FROM sensor_readings sr
    JOIN sensors s ON s.id = sr.sensor_id
    WHERE s.sensor_code = 'LAG-ENV-001' AND sr.recorded_at = NOW() - INTERVAL '90 minutes'
);
SELECT insert_sensor_reading('ENU-ENV-001', NOW() - INTERVAL '45 minutes', 12.00, 22.00)
WHERE NOT EXISTS (
    SELECT 1 FROM sensor_readings sr
    JOIN sensors s ON s.id = sr.sensor_id
    WHERE s.sensor_code = 'ENU-ENV-001' AND sr.recorded_at = NOW() - INTERVAL '45 minutes'
);
