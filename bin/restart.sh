#!/bin/bash
set -e

# Script to restart a Quadlet service on the homelab server

# Check if service name was provided
if [ -z "$1" ]; then
	echo "Usage: $0 <service-name>"
	echo ""
	echo "Available services:"
	echo "  pihole     - DNS ad blocker"
	echo "  caddy      - Reverse proxy"
	echo "  linkding   - Bookmark manager"
	echo "  n8n        - Workflow automation"
	echo "  mealie     - Recipe manager"
	echo ""
	echo "Example: $0 n8n"
	exit 1
fi

SERVICE_NAME="$1"

# Always use VPN IP (SSH port 22 is closed on public IP)
SERVER_IP="10.0.0.1"

echo "Restarting $SERVICE_NAME service on $SERVER_IP..."

# Restart the service
ssh root@$SERVER_IP "sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) systemctl --user restart ${SERVICE_NAME}.service"

if [ $? -eq 0 ]; then
	echo "✓ Service restarted successfully"

	# Wait a moment for the service to start
	sleep 2

	# Check service status
	echo ""
	echo "Service status:"
	ssh root@$SERVER_IP "sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) systemctl --user is-active ${SERVICE_NAME}.service" 2>/dev/null &&
		echo "✓ ${SERVICE_NAME} is running" ||
		echo "✗ ${SERVICE_NAME} failed to start"

	# Show recent logs
	echo ""
	echo "Recent logs (last 5 lines):"
	ssh root@$SERVER_IP "sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) journalctl --user -u ${SERVICE_NAME}.service -n 5 --no-pager" 2>/dev/null
else
	echo "✗ Failed to restart service"
	echo "Check logs with:"
	echo "  ssh root@$SERVER_IP 'sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) journalctl --user -u ${SERVICE_NAME}.service -f'"
	exit 1
fi
