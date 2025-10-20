#!/bin/bash
set -e

# Deploy quadlet services from Git repository using GNU Stow
# This script should be run on the server (as podman user)
# Usage: ssh hetzner 'sudo -u podman /home/podman/homelab-quadlets/bin/deploy.sh'

SERVICES=(
	caddy
	cloudflared
	config
	homepage
	linkding
	mcp-hub
	mealie
	n8n
	pihole
	plane
	readeck
	uptime-kuma
)
INACTIVE_SERVICES=(
	homepage
	uptime-kuma
)
REPO_DIR="/home/podman/homelab-quadlets"
REPO_URL="https://github.com/albandiguer/homelab-quadlets.git"

# Clone or update repository
if [ ! -d "$REPO_DIR" ]; then
	echo "Cloning repository..."
	git clone "$REPO_URL" "$REPO_DIR"
else
	echo "Updating repository..."
	cd "$REPO_DIR"
	git pull
fi

cd "$REPO_DIR"

echo ""
echo "Removing inactive services..."

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

for service in "${INACTIVE_SERVICES[@]}"; do
	if [ ! -d "$service" ]; then
		continue
	fi

	echo "  Stopping and disabling $service..."
	# Stop service if running
	systemctl --user stop "${service}.service" 2>/dev/null || true
	# Disable service if enabled
	systemctl --user disable "${service}.service" 2>/dev/null || true

	echo "  Unstowing $service..."
	stow --delete --target="$HOME" "$service" 2>/dev/null || true
done

systemctl --user daemon-reload 2>/dev/null || true

echo ""
echo "Deploying quadlet services with GNU Stow..."

for service in "${SERVICES[@]}"; do
	# Skip if in inactive list
	if [[ " ${INACTIVE_SERVICES[@]} " =~ " ${service} " ]]; then
		echo "  ⊘ Service '$service' is inactive, skipping"
		continue
	fi
	if [ ! -d "$service" ]; then
		echo "  ⊘ Service '$service' not found, skipping"
		continue
	fi

	echo "  Installing $service..."
	stow --restow --target="$HOME" "$service"
done

echo ""
echo "✓ Services deployed successfully"
echo ""
echo "Reloading systemd user daemon..."
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user daemon-reload

echo ""
echo "✓ Deployment complete!"
echo ""
echo "Services are now available. Start them with:"
echo "  systemctl --user start <service>.service"
