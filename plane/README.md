# Plane - Open Source Project Management

Plane is an open-source alternative to Jira, Linear, and Monday for project management.

## Architecture

This deployment uses a Podman pod with the following services:

- **plane-pod**: Main pod exposing port 8085 → 3000
- **plane-db**: PostgreSQL 15 database
- **plane-redis**: Redis cache and queue
- **plane-minio**: MinIO S3-compatible object storage
- **plane-api**: Backend API server
- **plane-worker**: Background job processor
- **plane-web**: Next.js frontend application

All services communicate via localhost within the pod network.

## Setup Instructions

### 1. Initialize Secrets

Run the secrets initialization script from your local machine:

```bash
./bin/init-secrets.sh
```

This will prompt you for the following Plane secrets:
- `plane_db_password` - PostgreSQL database password
- `plane_database_url` - Full database connection URL (format: `postgresql://plane:PASSWORD@localhost:5432/plane`)
- `plane_secret_key` - Application secret (generate with: `openssl rand -hex 32`)
- `plane_minio_root_password` - MinIO root password

### 2. Deploy Services

From your local machine:

```bash
# Deploy to server (will pull latest from git and install with stow)
ssh hetzner 'sudo -u podman /home/podman/homelab-quadlets/bin/deploy.sh'
```

### 3. Start Services

```bash
ssh hetzner
sudo -u podman bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Start the pod and all services
systemctl --user start plane-pod.service

# Check status of all Plane services
systemctl --user list-units "plane-*" --all

# Or check individual services
systemctl --user status plane-pod.service
systemctl --user status plane-db.service
systemctl --user status plane-redis.service
systemctl --user status plane-minio.service
systemctl --user status plane-api.service
systemctl --user status plane-worker.service
systemctl --user status plane-web.service
```

### 4. Initialize MinIO Bucket

Once services are running, create the S3 bucket:

```bash
# Access MinIO via the pod
podman exec -it plane-minio sh

# Set up MinIO alias (use your PLANE_MINIO_ROOT_PASSWORD)
mc alias set myminio http://localhost:9000 minioadmin your-minio-password

# Create bucket
mc mb myminio/plane

# Set public download policy (required for Plane)
mc anonymous set download myminio/plane

# Exit container
exit
```

### 5. Run Database Migrations

```bash
# Run Django migrations in the API container
podman exec -it plane-api python manage.py migrate
```

## Access

- **Web UI**: http://plane.lab or http://plane.lab.albandiguer.dev (via VPN)
- **MinIO Console**: Access via `podman exec -it plane-minio sh` if needed

## Restart Services

```bash
# From your local machine
ssh hetzner 'sudo -u podman /home/podman/homelab-quadlets/bin/restart.sh plane-pod'

# On the server
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user restart plane-pod.service
```

## View Logs

```bash
ssh hetzner
sudo -u podman bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# All services
journalctl --user -u plane-pod.service -f

# Individual services
journalctl --user -u plane-web.service -f
journalctl --user -u plane-api.service -f
journalctl --user -u plane-worker.service -f
journalctl --user -u plane-db.service -f
```

## Troubleshooting

### Services won't start
- Check environment variables are set: `printenv | grep PLANE_`
- Verify you logged out and back in after editing plane.conf
- Check logs: `journalctl --user -u plane-api.service`

### Can't access web interface
- Verify pod is running: `podman pod ps`
- Check port mapping: `podman port plane-pod`
- Verify Caddy is running and restart if needed

### Database connection errors
- Ensure plane-db is healthy: `podman healthcheck run plane-db`
- Check PostgreSQL logs: `journalctl --user -u plane-db.service`

## Data Persistence

All data is stored in `${QUADLET_STORAGE_PATH}/plane/`:
- `pgdata/` - PostgreSQL database
- `redis/` - Redis data
- `minio/` - Object storage
- `uploads/` - Uploaded files

This defaults to `/mnt/homelab-data/plane/` on your Hetzner server.
