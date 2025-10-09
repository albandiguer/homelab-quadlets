#!/bin/bash
set -e

# Deploy quadlet services using GNU Stow
# Usage: ./deploy.sh [service...]
# Examples:
#   ./deploy.sh              # Deploy all services
#   ./deploy.sh pihole caddy # Deploy specific services

SERVICES=(pihole caddy linkding n8n mcp-hub cloudflared mealie readeck)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUADLETS_DIR="$(dirname "$SCRIPT_DIR")"

# If arguments provided, use them; otherwise use all services
if [ $# -gt 0 ]; then
	DEPLOY_SERVICES=("$@")
else
	DEPLOY_SERVICES=("${SERVICES[@]}")
fi

cd "$QUADLETS_DIR"

echo "Deploying quadlet services with GNU Stow..."

for service in "${DEPLOY_SERVICES[@]}"; do
	if [ ! -d "$service" ]; then
		echo "✗ Service '$service' not found"
		exit 1
	fi

	echo "  Installing $service..."
	stow --restow --target="$HOME" "$service"
done

echo ""
echo "✓ Services deployed successfully"
echo ""
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

echo ""
echo "✓ Deployment complete!"
echo ""
echo "Services are now available. Start them with:"
echo "  systemctl --user start <service>.service"
