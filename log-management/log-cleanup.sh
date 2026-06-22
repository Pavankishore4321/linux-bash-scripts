#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Script:   log-cleanup.sh
# Purpose:  Clean old log files and compress logs older than N days
# Project:  On-Premises Server Maintenance (Incresol Software Services)
# Usage:    bash log-cleanup.sh
# Cron:     0 3 * * *  /etc/scripts/log-cleanup.sh  (daily at 3AM)
# ─────────────────────────────────────────────────────────────────────────────

# ── CONFIG ────────────────────────────────────────────────────────────────────
LOG_FILE="/var/log/log-cleanup.log"
COMPRESS_AFTER_DAYS=3     # compress logs older than 3 days
DELETE_AFTER_DAYS=30      # delete logs older than 30 days

# Directories to clean (add your app log paths here)
LOG_DIRS=(
    "/var/log/nginx"
    "/var/log/tomcat9"
    "/var/log/mongodb"
    "/var/log/app"
    "/opt/tomcat/logs"
)

# ── FUNCTIONS ─────────────────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
log "===== Log Cleanup Started ====="

TOTAL_FREED=0

for DIR in "${LOG_DIRS[@]}"; do
    if [ ! -d "$DIR" ]; then
        log "Skipping (not found): ${DIR}"
        continue
    fi

    log "Processing: ${DIR}"

    # Compress logs older than COMPRESS_AFTER_DAYS (not already compressed)
    find "$DIR" -type f -name "*.log" -mtime +"$COMPRESS_AFTER_DAYS" \
        ! -name "*.gz" -exec gzip {} \;
    COMPRESSED=$(find "$DIR" -name "*.gz" -newer "$LOG_FILE" | wc -l)
    log "  Compressed ${COMPRESSED} files in ${DIR}"

    # Delete compressed logs older than DELETE_AFTER_DAYS
    BEFORE=$(du -sh "$DIR" 2>/dev/null | cut -f1)
    find "$DIR" -type f -name "*.gz" -mtime +"$DELETE_AFTER_DAYS" -delete
    AFTER=$(du -sh "$DIR" 2>/dev/null | cut -f1)
    log "  Space before: ${BEFORE} | After: ${AFTER}"
done

log "===== Log Cleanup Finished ====="
