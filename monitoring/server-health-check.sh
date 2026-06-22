#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Script:   server-health-check.sh
# Purpose:  Monitor disk, CPU, memory and log alerts
# Project:  On-Premises Server Maintenance, IDigiPro (Incresol)
# Usage:    bash server-health-check.sh
# Cron:     */30 * * * *  /etc/scripts/server-health-check.sh  (every 30 mins)
# ─────────────────────────────────────────────────────────────────────────────

# ── CONFIG ────────────────────────────────────────────────────────────────────
LOG_FILE="/var/log/server-health.log"
ALERT_LOG="/var/log/server-alerts.log"

DISK_THRESHOLD=80      # alert if disk usage exceeds 80%
CPU_THRESHOLD=85       # alert if CPU usage exceeds 85%
MEM_THRESHOLD=85       # alert if memory usage exceeds 85%

# Services to check (add your services here)
SERVICES=(
    "nginx"
    "tomcat"
    "mongod"
    "docker"
    "sshd"
)

# ── FUNCTIONS ─────────────────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
    echo "[ALERT][$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$ALERT_LOG"
}

# ── DISK CHECK ─────────────────────────────────────────────────────────────────
check_disk() {
    log "── Disk Usage Check ──"
    df -h | grep -vE '^Filesystem|tmpfs|cdrom' | while read LINE; do
        USAGE=$(echo "$LINE" | awk '{print $5}' | sed 's/%//')
        MOUNT=$(echo "$LINE" | awk '{print $6}')

        if [ "$USAGE" -gt "$DISK_THRESHOLD" ]; then
            alert "Disk CRITICAL: ${MOUNT} is at ${USAGE}% (threshold: ${DISK_THRESHOLD}%)"
        else
            log "Disk OK: ${MOUNT} at ${USAGE}%"
        fi
    done
}

# ── CPU CHECK ─────────────────────────────────────────────────────────────────
check_cpu() {
    log "── CPU Usage Check ──"
    CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d. -f1)
    CPU_USAGE=$((100 - CPU_IDLE))

    if [ "$CPU_USAGE" -gt "$CPU_THRESHOLD" ]; then
        alert "CPU CRITICAL: Usage is at ${CPU_USAGE}% (threshold: ${CPU_THRESHOLD}%)"
        # Log top 5 processes consuming CPU
        log "Top CPU processes:"
        ps aux --sort=-%cpu | head -6 | tail -5 | tee -a "$LOG_FILE"
    else
        log "CPU OK: ${CPU_USAGE}% used"
    fi
}

# ── MEMORY CHECK ──────────────────────────────────────────────────────────────
check_memory() {
    log "── Memory Usage Check ──"
    TOTAL=$(free -m | awk 'NR==2{print $2}')
    USED=$(free -m  | awk 'NR==2{print $3}')
    MEM_USAGE=$(( (USED * 100) / TOTAL ))

    if [ "$MEM_USAGE" -gt "$MEM_THRESHOLD" ]; then
        alert "Memory CRITICAL: ${MEM_USAGE}% used (${USED}MB / ${TOTAL}MB)"
        log "Top memory processes:"
        ps aux --sort=-%mem | head -6 | tail -5 | tee -a "$LOG_FILE"
    else
        log "Memory OK: ${MEM_USAGE}% used (${USED}MB / ${TOTAL}MB)"
    fi
}

# ── SERVICE CHECK ──────────────────────────────────────────────────────────────
check_services() {
    log "── Service Status Check ──"
    for SERVICE in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$SERVICE"; then
            log "Service OK: ${SERVICE} is running"
        else
            alert "Service DOWN: ${SERVICE} is NOT running — attempting restart"
            systemctl restart "$SERVICE"
            sleep 5
            if systemctl is-active --quiet "$SERVICE"; then
                log "Service RECOVERED: ${SERVICE} restarted successfully"
            else
                alert "Service FAILED to restart: ${SERVICE} — manual intervention needed"
            fi
        fi
    done
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
log "========================================="
log "Server Health Check — $(hostname)"
log "========================================="

check_disk
check_cpu
check_memory
check_services

log "Health check complete."
