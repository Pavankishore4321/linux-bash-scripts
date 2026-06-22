#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Script:   vm-backup.sh
# Purpose:  KVM Virtual Machine backup using virsh + qcow2 copy
# Project:  On-Premises Server Maintenance (Incresol Software Services)
# Usage:    bash vm-backup.sh
# Cron:     0 2 * * 0  /etc/scripts/vm-backup.sh  (every Sunday at 2AM)
# ─────────────────────────────────────────────────────────────────────────────

# ── CONFIG ────────────────────────────────────────────────────────────────────
BACKUP_BASE="/backupvm3"
KVM_BASE="/kvm/vms2"
LOG_FILE="/var/log/vm-backup.log"
SHUTDOWN_WAIT=60     # seconds to wait after shutdown before copying
STARTUP_WAIT=30      # seconds to wait after start before checking state

# List of VMs to back up — add or remove VM names here
VMS=(
    "VM-SERVER-1"
    "VM-SERVER-2"
    "VM-SERVER-3"
)

# ── FUNCTIONS ─────────────────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_vm_state() {
    virsh domstate "$1" 2>/dev/null | tr -d '[:space:]'
}

backup_vm() {
    local VM_NAME="$1"
    local VM_DISK="${KVM_BASE}/${VM_NAME}/${VM_NAME}.qcow2"
    local BACKUP_DIR="${BACKUP_BASE}/${VM_NAME}"
    local VM_LOG="${BACKUP_DIR}/backup.log"

    log "──────────────────────────────────────"
    log "Starting backup for: ${VM_NAME}"

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Check VM is running before shutdown
    STATE=$(check_vm_state "$VM_NAME")
    if [ "$STATE" != "running" ]; then
        log "WARNING: ${VM_NAME} is not running (state: ${STATE}). Skipping."
        return 1
    fi

    # Step 1 — Shutdown VM
    log "Step 1: Shutting down ${VM_NAME}..."
    virsh shutdown "$VM_NAME"

    # Wait for VM to shut down
    log "Waiting ${SHUTDOWN_WAIT}s for VM to shut down..."
    sleep "$SHUTDOWN_WAIT"

    # Verify it's off
    STATE=$(check_vm_state "$VM_NAME")
    if [ "$STATE" != "shut off" ] && [ "$STATE" != "shutoff" ]; then
        log "ERROR: ${VM_NAME} did not shut down (state: ${STATE}). Forcing off."
        virsh destroy "$VM_NAME"
        sleep 10
    fi

    # Step 2 — Copy qcow2 disk image
    log "Step 2: Backing up disk image for ${VM_NAME}..."
    if [ -f "$VM_DISK" ]; then
        cp "$VM_DISK" "${BACKUP_DIR}/${VM_NAME}.qcow2"
        if [ $? -eq 0 ]; then
            log "Backup copy successful: ${BACKUP_DIR}/${VM_NAME}.qcow2"
        else
            log "ERROR: Backup copy FAILED for ${VM_NAME}"
        fi
    else
        log "ERROR: Disk file not found: ${VM_DISK}"
    fi

    # Step 3 — Start VM
    log "Step 3: Starting ${VM_NAME}..."
    virsh start "$VM_NAME"
    sleep "$STARTUP_WAIT"

    # Verify VM started
    STATE=$(check_vm_state "$VM_NAME")
    log "VM state after start: ${STATE}"

    # Step 4 — Write to VM-specific log
    echo "$(date '+%Y-%m-%d %H:%M:%S') | Backup done | State: ${STATE}" >> "$VM_LOG"
    log "Backup complete for: ${VM_NAME}"
    log "──────────────────────────────────────"
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
log "===== VM Backup Started ====="
log "Total VMs to back up: ${#VMS[@]}"

for VM in "${VMS[@]}"; do
    backup_vm "$VM"
done

log "===== VM Backup Finished ====="
