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

echo "Applying schema..."
psql \
  -v ON_ERROR_STOP=1 \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -f /sql/01_schema.sql

existing_sensors="$(psql \
  -tA \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -c 'SELECT COUNT(*) FROM sensors')"

existing_readings="$(psql \
  -tA \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -c 'SELECT COUNT(*) FROM sensor_readings')"

if [ "$existing_sensors" = "0" ] && [ "$existing_readings" = "0" ]; then
  echo "Database is empty. Applying seed data..."
  psql \
    -v ON_ERROR_STOP=1 \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -f /sql/02_seed.sql
else
  echo "Seed skipped because the database already contains data."
fi
