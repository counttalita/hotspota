#!/bin/bash

# Database Restore Script with AES-256 Decryption
# Usage: ./scripts/restore_database.sh <backup_file> [environment]
# Example: ./scripts/restore_database.sh backups/hotspot_production_20241031_120000.sql.enc production

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <backup_file> [environment]"
  echo "Example: $0 backups/hotspot_production_20241031_120000.sql.enc production"
  exit 1
fi

BACKUP_FILE=$1
ENVIRONMENT=${2:-production}
TEMP_DIR="temp_restore"

# Create temp directory
mkdir -p "$TEMP_DIR"

echo "Starting database restore for ${ENVIRONMENT}..."

# Load environment variables
if [ -f ".env.${ENVIRONMENT}" ]; then
  source ".env.${ENVIRONMENT}"
fi

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
  echo "Error: DATABASE_URL not set"
  exit 1
fi

# Extract database connection details
DB_USER=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
DB_PASS=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
DB_HOST=$(echo "$DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
DB_PORT=$(echo "$DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
DB_NAME=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file not found: $BACKUP_FILE"
  exit 1
fi

# Decrypt if encrypted
if [[ "$BACKUP_FILE" == *.enc ]]; then
  echo "Decrypting backup..."

  if [ -z "$BACKUP_ENCRYPTION_KEY" ]; then
    echo "Error: BACKUP_ENCRYPTION_KEY not set"
    exit 1
  fi

  DECRYPTED_FILE="${TEMP_DIR}/$(basename ${BACKUP_FILE%.enc})"

  openssl enc -aes-256-cbc -d -pbkdf2 \
    -in "$BACKUP_FILE" \
    -out "$DECRYPTED_FILE" \
    -pass "pass:$BACKUP_ENCRYPTION_KEY"

  RESTORE_FILE="$DECRYPTED_FILE"
else
  RESTORE_FILE="$BACKUP_FILE"
fi

# Confirm restore
echo "WARNING: This will overwrite the database: $DB_NAME"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Restore cancelled"
  rm -rf "$TEMP_DIR"
  exit 0
fi

# Drop existing connections
echo "Dropping existing connections..."
PGPASSWORD="$DB_PASS" psql \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d postgres \
  -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"

# Restore database
echo "Restoring database..."
PGPASSWORD="$DB_PASS" pg_restore \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  --clean \
  --if-exists \
  "$RESTORE_FILE"

# Clean up
rm -rf "$TEMP_DIR"

echo "Database restore completed successfully!"
