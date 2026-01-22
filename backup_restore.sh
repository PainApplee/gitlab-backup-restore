#!/bin/bash

BACKUP="buckup_filename_without_extension"
#Example: 1768014105_2026_01_10_18.4.5-ee
DISK="your/mount/point"
IP="your.server.ip.address"

# Waiting function
# Waiting for a container to be running
wait_for_container() {
	local name="$1"
	local timeout=${2:-120}
	local interval=5
	local waited=0
	echo "Waiting for container '$name' (timeout ${timeout}s)..."
	while [ $waited -lt $timeout ]; do
		if docker ps --filter "name=$name" --filter "status=running" -q | grep -q .; then
			echo "Container '$name' is running"
			return 0
		fi
		sleep $interval
		waited=$((waited + interval))
	done

	echo "Timeout: container '$name' did not start within ${timeout}s"
	return 1
}

# Installing Docker and docker-compose
echo "Stage 1: Installing Docker"
sudo apt update 
sudo apt -y upgrade
echo "SYSTEM UPDATE COMPLETED"
sudo apt install docker.io -y 
sudo apt install docker-compose-v2 -y
echo "DOCKER AND DOCKER-COMPOSE INSTALLED"

# Preparing directories
echo "Stage 2: Preparing directories"
mkdir -p $DISK/gitlab/glh/{config,logs,data}
cp /srv/gitlab_backup/gitlab-secrets.json $DISK/gitlab/glh/
cp /srv/gitlab_backup/.env $DISK/gitlab/glh/
cp /srv/gitlab_backup/docker-compose.yml $DISK/gitlab/glh/
cd $DISK/gitlab/glh

# Starting Gitlab container
echo "Stage 3: Starting Gitlab"
docker compose up -d
if ! wait_for_container gitlab 120; then
	echo "Error: container 'gitlab' did not start"
	exit 1
fi
docker exec -t gitlab gitlab-ctl reconfigure
docker exec -t gitlab gitlab-ctl status

# Restoring from backup
echo "Stage 4: Starting backup restoration"
docker exec -t gitlab gitlab-ctl stop puma
docker exec -t gitlab gitlab-ctl stop sidekiq
mkdir -p $DISK/gitlab/glh/data/backups
tar -tf /srv/gitlab_backup/*_gitlab_backup.tar > /dev/null && echo "Backup status - OK" || echo "Backup status - DAMAGED"
cp /srv/gitlab_backup/*_gitlab_backup.tar $DISK/gitlab/glh/data/backups/
docker exec -e BACKUP=$BACKUP -t gitlab gitlab-backup restore force=yes
docker exec -t gitlab gitlab-ctl status

# Recongiguring and restarting Gitlab
echo "Stage 5: Restarting Gitlab after restoration"
docker exec -t gitlab gitlab-ctl reconfigure
docker exec -t gitlab gitlab-ctl restart
docker exec -t gitlab gitlab-ctl status
echo "Restoration completed"

# Starting Caddy server
echo "Stage 6: Starting Caddy"
mkdir -p /opt/caddy
cp /srv/gitlab_backup/caddy/* /opt/caddy
cd /opt/caddy
docker compose up -d
echo "Caddy started successfully"




