#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Script:   nfs-mount-setup.sh
# Purpose:  Setup, mount, and verify NFS/SMB shared drives
# Project:  IDigiPro, On-Premises Server Maintenance (Incresol Software Services)
# Usage:    sudo bash nfs-mount-setup.sh
# ─────────────────────────────────────────────────────────────────────────────

# ── CONFIG ────────────────────────────────────────────────────────────────────
LOG_FILE="/var/log/nfs-setup.log"

# NFS mounts — format: "server:/share /local/mountpoint"
NFS_MOUNTS=(
    "nfs-server-1:/data/shared    /mnt/shared"
    "nfs-server-1:/data/backups   /mnt/backups"
    "nfs-server-2:/data/archive   /mnt/archive"
)

# SMB/CIFS mounts — format: "//server/share /local/mountpoint username password"
SMB_MOUNTS=(
    "//smb-server/shared  /mnt/smb-shared  smbuser  smbpassword"
)

# ── FUNCTIONS ─────────────────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ── INSTALL DEPENDENCIES ──────────────────────────────────────────────────────
log "===== NFS/SMB Mount Setup Started ====="

log "Installing NFS and CIFS utilities..."
apt update -y
apt install -y nfs-common cifs-utils
log "Dependencies installed."

# ── SETUP NFS MOUNTS ──────────────────────────────────────────────────────────
log "Setting up NFS mounts..."

for MOUNT in "${NFS_MOUNTS[@]}"; do
    SERVER_SHARE=$(echo "$MOUNT" | awk '{print $1}')
    LOCAL_MOUNT=$(echo "$MOUNT"  | awk '{print $2}')

    # Create mount point
    mkdir -p "$LOCAL_MOUNT"

    # Check if already mounted
    if mountpoint -q "$LOCAL_MOUNT"; then
        log "Already mounted: ${LOCAL_MOUNT}"
        continue
    fi

    # Mount NFS share
    mount -t nfs "$SERVER_SHARE" "$LOCAL_MOUNT" -o defaults,_netdev
    if [ $? -eq 0 ]; then
        log "NFS mounted: ${SERVER_SHARE} → ${LOCAL_MOUNT}"

        # Add to /etc/fstab for persistence across reboots
        if ! grep -q "$LOCAL_MOUNT" /etc/fstab; then
            echo "${SERVER_SHARE}  ${LOCAL_MOUNT}  nfs  defaults,_netdev  0  0" >> /etc/fstab
            log "Added to /etc/fstab: ${SERVER_SHARE}"
        fi
    else
        log "ERROR: Failed to mount NFS: ${SERVER_SHARE}"
    fi
done

# ── SETUP SMB MOUNTS ──────────────────────────────────────────────────────────
log "Setting up SMB/CIFS mounts..."

for MOUNT in "${SMB_MOUNTS[@]}"; do
    SMB_SHARE=$(echo  "$MOUNT" | awk '{print $1}')
    LOCAL_MOUNT=$(echo "$MOUNT" | awk '{print $2}')
    SMB_USER=$(echo   "$MOUNT" | awk '{print $3}')
    SMB_PASS=$(echo   "$MOUNT" | awk '{print $4}')

    mkdir -p "$LOCAL_MOUNT"

    if mountpoint -q "$LOCAL_MOUNT"; then
        log "Already mounted: ${LOCAL_MOUNT}"
        continue
    fi

    mount -t cifs "$SMB_SHARE" "$LOCAL_MOUNT" \
        -o username="$SMB_USER",password="$SMB_PASS",vers=3.0
    if [ $? -eq 0 ]; then
        log "SMB mounted: ${SMB_SHARE} → ${LOCAL_MOUNT}"
    else
        log "ERROR: Failed to mount SMB: ${SMB_SHARE}"
    fi
done

# ── VERIFY ALL MOUNTS ─────────────────────────────────────────────────────────
log "── Verifying all mounts ──"
df -h | grep -E "mnt|nfs|smb|cifs" | tee -a "$LOG_FILE"

log "===== NFS/SMB Mount Setup Complete ====="
