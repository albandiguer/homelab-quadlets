#!/bin/bash
set -e

# Restart a quadlet service
# Usage: ./restart.sh <service-name>

if [ -z "$1" ]; then
	echo "Usage: $0 <service-name>"
	echo ""
	echo "Available services:"
	echo "  pihole     - DNS ad blocker"
	echo "  caddy      - Reverse proxy"
	echo "  linkding   - Bookmark manager"
	echo "  n8n        - Workflow automation"
	echo "  mcp-hub    - MCP Hub"
	echo "  cloudflared - Cloudflare tunnel"
	echo "  mealie     - Recipe manager"
	echo "  readeck    - Reading list"
	echo ""
	echo "Example: $0 n8n"
	exit 1
fi

SERVICE_NAME="$1"

echo "Restarting $SERVICE_NAME service..."
systemctl --user restart "${SERVICE_NAME}.service"

if [ $? -eq 0 ]; then
	echo "✓ Service restarted successfully"

	sleep 2

	echo ""
	echo "Service status:"
	systemctl --user is-active "${SERVICE_NAME}.service" 2>/dev/null &&
		echo "✓ ${SERVICE_NAME} is running" ||
		echo "✗ ${SERVICE_NAME} failed to start"

	echo ""
	echo "Recent logs (last 10 lines):"
	journalctl --user -u "${SERVICE_NAME}.service" -n 10 --no-pager 2>/dev/null
else
	echo "✗ Failed to restart service"
	echo "Check logs with:"
	echo "  journalctl --user -u ${SERVICE_NAME}.service -f"
	exit 1
fi
