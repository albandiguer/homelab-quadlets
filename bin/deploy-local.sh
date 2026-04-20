#!/bin/bash
set -e

# Deploy quadlets from your local machine to the server (single command)
# Usage: ./deploy-local.sh [service1 service2 ...]
#
# Without arguments: pushes and deploys (stow + daemon-reload)
# With arguments: also restarts the specified services and shows logs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUADLETS_DIR="$(dirname "$SCRIPT_DIR")"

# Run a command as the podman user on minilab
# minilab-podman has RemoteCommand/RequestTTY set for interactive use,
# so we override those and use sudo -u podman -i for non-interactive commands.
run_on_minilab() {
	ssh -o RemoteCommand=none -o RequestTTY=no minilab-podman \
		"sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u podman)/bus $1"
}

# Step 1: Push to server
echo "Pushing to server..."
cd "$QUADLETS_DIR"
git push minilab main

# Step 2: Deploy (stow + daemon-reload)
echo "Deploying on server..."
run_on_minilab '/home/podman/homelab-quadlets/bin/deploy.sh'

# Step 3: Restart services if specified
if [ $# -gt 0 ]; then
	for service in "$@"; do
		# Map directory names to actual systemd service names
		case "$service" in
		plane) service_unit="plane-pod" ;;
		*) service_unit="$service" ;;
		esac
		echo "Restarting $service..."
		run_on_minilab "systemctl --user restart ${service_unit}.service"
		echo "--- Last 20 log lines for $service ---"
		run_on_minilab "journalctl --user -u ${service_unit}.service -n 20 --no-pager"
	done
fi

echo "Done!"
