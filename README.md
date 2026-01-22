# GitLab Backup Restoration Script

## Description

The `backup_restore.sh` script automates the process of deploying GitLab from a backup on a new server. It performs a complete recovery cycle, including Docker installation, directory preparation, GitLab container startup, and data restoration from backup.

## Requirements

- **OS**: Linux (Ubuntu/Debian)
- **Access Rights**: Sudo privileges
- **Pre-installed Files**:
  - `/srv/gitlab_backup/gitlab-secrets.json` - GitLab secrets configuration
  - `/srv/gitlab_backup/.env` - environment variables
  - `/srv/gitlab_backup/docker-compose.yml` - Docker Compose config
  - `/srv/gitlab_backup/*_gitlab_backup.tar` - GitLab backup file 
  - `/srv/gitlab_backup/caddy/*` - Caddy web server configs

## Preparation Before Running

1. **Edit the variables in the script**:
   ```bash
   GITLAB_HOME="/your/mount/point/gitlab/glh"
   #Example: /mnt/gitlab/glh
   BACKUP="buckup_filename_without_extension"
   #Example: 1768014105_2026_01_10_18.4.5-ee
   DISK="your/mount/point"           # Path to mount point for data storage
   IP="your.server.ip.address"       # Server IP address
   ```

2. **Ensure that necessary files are present** in `/srv/gitlab_backup/`

3. **Grant execution permissions**:
   ```bash
   chmod +x backup_skript.sh
   ```

## How to Use

Run the script with superuser privileges:

```bash
sudo ./backup_skript.sh
```

## Execution Stages

### Stage 1: Docker Installation
- Updates the system (`apt update`, `apt upgrade`)
- Installs Docker and Docker Compose v2

### Stage 2: Directory Preparation
- Creates directory structure: `$DISK/gitlab/glh/{config,logs,data}`
- Copies configuration files from `/srv/gitlab_backup/`

### Stage 3: Starting GitLab
- Starts GitLab container via `docker compose up`
- Waits for container readiness (120 sec timeout)
- Performs reconfiguration (`gitlab-ctl reconfigure`)
- Checks status

### Stage 4: Backup Restoration
- Stops Puma and Sidekiq
- Verifies backup file integrity
- Copies backup to `$DISK/gitlab/glh/data/backups/`
- Performs restoration (`gitlab-backup restore`)

### Stage 5: GitLab Restart
- Reconfigures GitLab
- Restarts all services
- Checks final status

### Stage 6: Starting Caddy
- Prepares `/opt/caddy` directory
- Copies Caddy configs
- Adds entry to `/etc/hosts`
- Starts Caddy container

## Container Waiting Function

The script contains a `wait_for_container` function that:
- Waits for the specified container to start
- Has configurable timeout (default 120 sec)
- Checks status every 5 seconds
- Returns error if container did not start in time

## Possible Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Container 'gitlab' did not start" | GitLab container failed to start | Check logs: `docker logs gitlab` |
| Permission denied | Insufficient privileges | Run with `sudo` |
| File not found | Missing configs | Check files in `/srv/gitlab_backup/` |
| DAMAGED | Corrupted backup file | Verify backup `.tar` file integrity |

## Output

The script outputs information about each execution stage:
```
Stage 1: Installing Docker
SYSTEM UPDATE COMPLETED
DOCKER AND DOCKER-COMPOSE INSTALLED
Stage 2: Preparing directories
...
Restoration successfully completed
Caddy started successfully
```

## Logging

To save execution logs:
```bash
sudo ./backup_skript.sh | tee backup_$(date +%Y%m%d_%H%M%S).log
```

## Important Notes

WARNING:
- Requires internet connection to download Docker packages
- May take 5-15 minutes depending on backup size
- Recommended to test on staging environment before running on production

## Support and Troubleshooting

If problems occur, check:
1. Container logs: `docker logs gitlab`
2. Service status: `docker compose ps`
3. Presence of necessary files in `/srv/gitlab_backup/`
