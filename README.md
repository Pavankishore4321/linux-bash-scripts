# linux-bash-scripts

Shell scripts and Ansible automation built from real on-premises and cloud deployments
at **Incresol Software Services**. Used for VM backup automation, database backups,
server health monitoring, NFS/SMB mount management, and Linux server hardening.

---

## Repository Structure

```
linux-bash-scripts/
├── vm-management/
│   ├── vm_backup.yml              # Ansible: KVM VM backup (shutdown → copy → start)
│   └── vm-backup.sh               # Shell: same VM backup logic for cron scheduling
├── backup/
│   └── db-backup.sh               # MySQL + MongoDB backup with S3 upload
├── monitoring/
│   └── server-health-check.sh     # Disk, CPU, memory, service monitoring + auto-restart
├── server-setup/
│   ├── initial-server-setup.sh    # New Linux server bootstrap + SSH hardening + UFW
│   └── nfs-mount-setup.sh         # NFS/SMB shared drive setup and fstab persistence
├── log-management/
│   └── log-cleanup.sh             # Compress old logs, delete expired logs
└── README.md
```

---

## Script Details

### vm-management/vm_backup.yml + vm-backup.sh
**Project: On-Premises Server Maintenance (Incresol)**

Automates KVM virtual machine backup on bare-metal on-premises servers.

**How it works:**
1. Checks backup directory exists
2. Gracefully shuts down each KVM VM using `virsh shutdown`
3. Waits 60 seconds for VM to fully power off
4. Copies the `.qcow2` disk image to the backup directory
5. Starts the VM back up using `virsh start`
6. Writes a timestamped log entry for each VM

**Two versions provided:**
- `vm_backup.yml` — Ansible playbook (loops over multiple VMs, idempotent)
- `vm-backup.sh` — Shell script (for direct cron scheduling)

```bash
# Run Ansible version
ansible-playbook vm-management/vm_backup.yml

# Run shell version directly
sudo bash vm-management/vm-backup.sh

# Add to cron (every Sunday at 2AM)
0 2 * * 0  /path/to/vm-backup.sh
```

---

### backup/db-backup.sh
**Projects: AspTax (MySQL), P-Collab (MongoDB)**

Backs up MySQL and MongoDB databases, compresses them, and uploads to AWS S3.

**What it does:**
- `mysqldump` with `--single-transaction` for live backup without locking tables
- `mongodump` for MongoDB databases
- Compresses all backups with gzip
- Uploads to S3 using `aws s3 sync`
- Deletes local backups older than 7 days

```bash
# Run manually
sudo bash backup/db-backup.sh

# Cron — daily at 1AM
0 1 * * *  /etc/scripts/db-backup.sh
```

---

### monitoring/server-health-check.sh
**Projects: On-Premises servers, IDigiPro, AspTax**

Monitors server health every 30 minutes and logs alerts.

**Checks performed:**
- **Disk usage** — alerts if any partition exceeds 80%
- **CPU usage** — alerts if CPU exceeds 85%, logs top processes
- **Memory usage** — alerts if RAM exceeds 85%, logs top processes
- **Service status** — checks nginx, tomcat, mongod, docker, sshd
- **Auto-restart** — automatically attempts to restart any stopped service

```bash
# Run manually
sudo bash monitoring/server-health-check.sh

# Cron — every 30 minutes
*/30 * * * *  /etc/scripts/server-health-check.sh
```

---

### server-setup/initial-server-setup.sh
**Projects: On-Premises Server Maintenance, IDigiPro**

One-command bootstrap script for fresh Ubuntu servers.

**What it does:**
- Updates all system packages
- Creates `devops` user with SSH key authentication
- Disables root SSH login and password authentication
- Configures UFW firewall (allow SSH, HTTP, HTTPS only)
- Sets timezone to Asia/Kolkata
- Installs: git, vim, htop, curl, fail2ban, logrotate, ntp
- Configures log rotation for application logs

```bash
sudo bash server-setup/initial-server-setup.sh
```

---

### server-setup/nfs-mount-setup.sh
**Projects: IDigiPro, On-Premises Server Maintenance**

Sets up NFS and SMB/CIFS shared drives on Linux servers.

**What it does:**
- Installs `nfs-common` and `cifs-utils`
- Mounts NFS and SMB shares to local mount points
- Adds entries to `/etc/fstab` so mounts survive server reboots
- Verifies all mounts are active

```bash
sudo bash server-setup/nfs-mount-setup.sh
```

---

### log-management/log-cleanup.sh
**Project: On-Premises Server Maintenance**

Automated log compression and cleanup to prevent disk full issues.

**What it does:**
- Compresses `.log` files older than 3 days using gzip
- Deletes compressed logs older than 30 days
- Covers: Nginx, Tomcat, MongoDB, and app log directories
- Logs before/after disk usage for each directory

```bash
# Run manually
sudo bash log-management/log-cleanup.sh

# Cron — daily at 3AM
0 3 * * *  /etc/scripts/log-cleanup.sh
```

---

## Cron Schedule Summary

| Script | Schedule | Purpose |
|---|---|---|
| `vm-backup.sh` | Every Sunday 2AM | KVM VM disk image backup |
| `db-backup.sh` | Daily 1AM | MySQL + MongoDB backup + S3 upload |
| `server-health-check.sh` | Every 30 mins | Disk, CPU, memory, service check |
| `log-cleanup.sh` | Daily 3AM | Compress + delete old log files |

---

## Real Projects These Scripts Supported

| Project | Client | Scripts Used |
|---|---|---|
| On-Premises VM Backup | Incresol internal | vm_backup.yml, vm-backup.sh |
| AspTax | Tax platform | db-backup.sh, server-health-check.sh |
| P-Collab | Collaboration tool | db-backup.sh |
| IDigiPro | Digital signature | nfs-mount-setup.sh, initial-server-setup.sh |
| On-Premises Maintenance | Incresol infra team | log-cleanup.sh, server-health-check.sh |

---

## Technologies Used

| Tool | Purpose |
|---|---|
| KVM / virsh | Virtual machine management |
| qcow2 | KVM VM disk image format |
| Ansible | Playbook-based VM backup automation |
| mysqldump | MySQL database backup |
| mongodump | MongoDB database backup |
| AWS S3 / aws cli | Cloud backup storage |
| UFW | Linux firewall management |
| NFS / CIFS | Network file system mounting |
| cron | Script scheduling |
| fail2ban | Brute force protection |

---

## Author

**Pavan Kishore Nakka**
DevOps & Cloud Engineer | 3+ Years Experience
AWS Certified Solutions Architect – Associate | AWS Certified Cloud Practitioner

[LinkedIn](https://www.linkedin.com/in/nakka-pavan-kishore)
