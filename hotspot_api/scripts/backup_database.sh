#!/bin/bash

# Database Backup Script with AES-256 Encryption
# Usage: ./scripts/backup_database.sh [environment]
# Example: ./scripts/backup_database.sh production

set -e

ENVIRONMENT=${1:-production}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups"
BACKUP_FILE="${BACKUP_DIR}/hotspot_${ENVIRONMENT}_${TIMESTAMP}.sql"
ENCRYPTED_FILE="${BACKUP_FILE}.enc"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Starting database backup for ${ENVIRONMENT}..."

# Load environment variables
if [ -f ".env.${ENVIRONMENT}" ]; then
  source ".env.${ENVIRONMENT}"
fi

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
  echo "Error: DATABASE_URL not set"
  exit 1
fi

# Extract database connection details from DATABASE_URL
# Format: postgresql://user:password@host:port/database
DB_USER=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
DB_PASS=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
DB_HOST=$(echo "$DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
DB_PORT=$(echo "$DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
DB_NAME=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')

# Create unencrypted backup
echo "Creating database dump..."
PGPASSWORD="$DB_PASS" pg_dump \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -F c \
  -f "$BACKUP_FILE"

# Check if backup was successful
if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file not created"
  exit 1
fi

echo "Database dump created: $BACKUP_FILE"

# Encrypt the backup
echo "Encrypting backup with AES-256..."

# Check if BACKUP_ENCRYPTION_KEY is set
if [ -z "$BACKUP_ENCRYPTION_KEY" ]; then
  echo "Warning: BACKUP_ENCRYPTION_KEY not set. Backup will not be encrypted."
  echo "Set BACKUP_ENCRYPTION_KEY environment variable for encryption."
else
  # Encrypt using AES-256-CBC with PBKDF2
  openssl enc -aes-256-cbc -salt -pbkdf2 \
    -in "$BACKUP_FILE" \
    -out "$ENCRYPTED_FILE" \
    -pass "pass:$BACKUP_ENCRYPTION_KEY"

  # Remove unencrypted backup
  rm "$BACKUP_FILE"

  echo "Encrypted backup created: $ENCRYPTED_FILE"
  BACKUP_FILE="$ENCRYPTED_FILE"
fi

# Get file size
FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "Backup size: $FILE_SIZE"

# Optional: Upload to cloud storage (S3, GCS, etc.)
if [ ! -z "$AWS_S3_BUCKET" ]; then
  echo "Uploading to S3..."
  aws s3 cp "$BACKUP_FILE" "s3://${AWS_S3_BUCKET}/backups/$(basename $BACKUP_FILE)"
  echo "Backup uploaded to S3"
fi

# Optional: Keep only last 30 days of backups
echo "Cleaning up old backups (keeping last 30 days)..."
find "$BACKUP_DIR" -name "hotspot_${ENVIRONMENT}_*.sql*" -mtime +30 -delete

echo "Backup completed successfully!"
echo "Backup file: $BACKUP_FILE"
