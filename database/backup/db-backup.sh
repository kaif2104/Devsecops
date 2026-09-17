#!/usr/bin/env bash

set -e

DB_HOST="${DB_HOST:-3.7.56.229}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-productdb}"
DB_USER="${DB_USER:-postgres}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/pg_backups}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_backup_${TIMESTAMP}.sql"

mkdir -p "${BACKUP_DIR}"

echo "=================================================="
echo " [DATABASE ENGINE] Taking Pre-Deployment Backup"
echo " Target DB: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo " Backup:    ${BACKUP_FILE}"
echo "=================================================="

# Take SQL dump
PGPASSWORD="${DB_PASSWORD:-postgres}" pg_dump \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d "${DB_NAME}" > "${BACKUP_FILE}"

echo ">> SUCCESS: Pre-deployment backup created: ${BACKUP_FILE}"

ls -lh "${BACKUP_FILE}"
