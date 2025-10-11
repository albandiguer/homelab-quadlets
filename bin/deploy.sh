#!/bin/bash
set -e

# Deploy quadlet services from Git repository using GNU Stow
# This script should be run on the server (as podman user)
# Usage: ssh hetzner 'sudo -u podman /home/podman/homelab-quadlets/bin/deploy.sh'

SERVICES=(config pihole caddy linkding n8n mcp-hub cloudflared mealie readeck uptime-kuma homepage)
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
echo "Deploying quadlet services with GNU Stow..."

for service in "${SERVICES[@]}"; do
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
