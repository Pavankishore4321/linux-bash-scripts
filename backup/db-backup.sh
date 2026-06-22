#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Script:   db-backup.sh
# Purpose:  Backup MySQL and MongoDB databases, compress, upload to S3
# Project:  AspTax, Spring Boot multi-client deployments (Incresol)
# Usage:    bash db-backup.sh
# Cron:     0 1 * * *  /etc/scripts/db-backup.sh  (every day at 1AM)
# ─────────────────────────────────────────────────────────────────────────────

# ── CONFIG ────────────────────────────────────────────────────────────────────
BACKUP_DIR="/var/backups/databases"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="/var/log/db-backup.log"
RETENTION_DAYS=7          # delete backups older than 7 days
S3_BUCKET="your-s3-bucket-name"
S3_PREFIX="db-backups"

# MySQL config
MYSQL_USER="backup_user"
MYSQL_PASS="your-mysql-password"   # use ~/.my.cnf in production
MYSQL_DATABASES=(
    "asptax_db"
    "client_app_db"
)

# MongoDB config
MONGO_HOST="localhost"
MONGO_PORT="27017"
MONGO_DATABASES=(
    "pcollab_db"
    "app_db"
)

# ── FUNCTIONS ─────────────────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ── SETUP ─────────────────────────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"
log "===== Database Backup Started ====="

# ── MYSQL BACKUPS ─────────────────────────────────────────────────────────────
log "Starting MySQL backups..."

for DB in "${MYSQL_DATABASES[@]}"; do
    BACKUP_FILE="${BACKUP_DIR}/${DB}_${DATE}.sql.gz"

    log "Backing up MySQL database: ${DB}"
    mysqldump \
        -u "$MYSQL_USER" \
        -p"$MYSQL_PASS" \
        --single-transaction \
        --routines \
        --triggers \
        "$DB" | gzip > "$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
        log "MySQL backup successful: ${BACKUP_FILE} (${SIZE})"
    else
        log "ERROR: MySQL backup FAILED for ${DB}"
    fi
done

# ── MONGODB BACKUPS ───────────────────────────────────────────────────────────
log "Starting MongoDB backups..."

for DB in "${MONGO_DATABASES[@]}"; do
    BACKUP_PATH="${BACKUP_DIR}/mongo_${DB}_${DATE}"

    log "Backing up MongoDB database: ${DB}"
    mongodump \
        --host "$MONGO_HOST" \
        --port "$MONGO_PORT" \
        --db "$DB" \
        --out "$BACKUP_PATH"

    if [ $? -eq 0 ]; then
        # Compress the dump
        tar -czf "${BACKUP_PATH}.tar.gz" -C "$BACKUP_DIR" "$(basename $BACKUP_PATH)"
        rm -rf "$BACKUP_PATH"
        SIZE=$(du -sh "${BACKUP_PATH}.tar.gz" | cut -f1)
        log "MongoDB backup successful: ${BACKUP_PATH}.tar.gz (${SIZE})"
    else
        log "ERROR: MongoDB backup FAILED for ${DB}"
    fi
done

# ── UPLOAD TO S3 ──────────────────────────────────────────────────────────────
log "Uploading backups to S3: s3://${S3_BUCKET}/${S3_PREFIX}/"

aws s3 sync "$BACKUP_DIR" "s3://${S3_BUCKET}/${S3_PREFIX}/" \
    --exclude "*" \
    --include "*${DATE}*"

if [ $? -eq 0 ]; then
    log "S3 upload successful."
else
    log "ERROR: S3 upload FAILED. Backups remain locally."
fi

# ── CLEANUP OLD BACKUPS ───────────────────────────────────────────────────────
log "Removing local backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -delete
log "Cleanup done."

log "===== Database Backup Finished ====="
