#!/bin/sh
set -eu

set -a
. /app/.env
set +a

export PGPASSWORD="$DB_PASSWORD"

echo "Waiting for PostgreSQL at $DB_HOST:$DB_PORT..."
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; do
  sleep 2
done

echo "Ensuring schema is present..."
psql \
  -v ON_ERROR_STOP=1 \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -f /sql/01_schema.sql

echo "Resetting demo tables..."
psql \
  -v ON_ERROR_STOP=1 \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" <<'SQL'
TRUNCATE TABLE sensor_readings, sensors, locations RESTART IDENTITY CASCADE;
SQL

echo "Applying seed data..."
psql \
  -v ON_ERROR_STOP=1 \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -f /sql/02_seed.sql
