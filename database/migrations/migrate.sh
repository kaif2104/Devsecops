#!/usr/bin/env bash

set -e

DB_HOST="${DB_HOST:-3.7.56.229}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-productdb}"
DB_USER="${DB_USER:-postgres}"

MIGRATIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================================="
echo " [DATABASE ENGINE] Step 1: Health Pre-flight Check"
echo " Checking PostgreSQL on ${DB_HOST}:${DB_PORT}..."
echo "=================================================="

if ! pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -t 5; then
    echo ">> [CRITICAL ERROR] PostgreSQL is NOT reachable on ${DB_HOST}:${DB_PORT}!"
    echo ">> Quality Gate Triggered: Pipeline aborted to prevent downtime."
    exit 1
fi

echo ">> [HEALTHY] PostgreSQL is accepting connections."

echo "=================================================="
echo " [DATABASE ENGINE] Step 2: Applying Migrations"
echo "=================================================="

export PGPASSWORD="${DB_PASSWORD:-postgres}"

psql -h "${DB_HOST}" \
     -p "${DB_PORT}" \
     -U "${DB_USER}" \
     -d "${DB_NAME}" \
     -v ON_ERROR_STOP=1 \
     -c "
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(100) PRIMARY KEY,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);"

for file in $(ls "${MIGRATIONS_DIR}"/V*.sql | sort); do
    filename=$(basename "$file")

    already_applied=$(psql \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        -tAc "SELECT 1 FROM schema_migrations WHERE version = '${filename}';")

    if [ "$already_applied" = "1" ]; then
        echo ">> [SKIPPED] ${filename} (already applied)"
    else
        echo ">> [APPLYING] ${filename}..."

        psql \
            -h "${DB_HOST}" \
            -p "${DB_PORT}" \
            -U "${DB_USER}" \
            -d "${DB_NAME}" \
            -v ON_ERROR_STOP=1 \
            -f "$file"

        echo ">> [SUCCESS] ${filename} applied successfully."
    fi
done

echo "=================================================="
echo " [DATABASE ENGINE] Database is Up-To-Date!"
echo "=================================================="
