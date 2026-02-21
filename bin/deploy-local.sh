#!/bin/bash
set -e

# Deploy quadlets from your local machine to the server (single command)
# Usage: ./deploy-local.sh [service1 service2 ...]
#
# Without arguments: pushes and deploys (stow + daemon-reload)
# With arguments: also restarts the specified services and shows logs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUADLETS_DIR="$(dirname "$SCRIPT_DIR")"

# Step 1: Push to server
echo "Pushing to server..."
cd "$QUADLETS_DIR"
git push minilab main

# Step 2: Deploy (stow + daemon-reload)
echo "Deploying on server..."
ssh minilab-podman '/home/podman/homelab-quadlets/bin/deploy.sh'

# Step 3: Restart services if specified
if [ $# -gt 0 ]; then
  for service in "$@"; do
    echo "Restarting $service..."
    ssh minilab-podman "systemctl --user restart ${service}.service"
    echo "--- Last 20 log lines for $service ---"
    ssh minilab-podman "journalctl --user -u ${service}.service -n 20 --no-pager"
  done
fi

echo "Done!"
