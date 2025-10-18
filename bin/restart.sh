#!/bin/bash
set -e

# Restart a quadlet service or pod
# Usage: ./restart.sh <service-name>

if [ -z "$1" ]; then
	echo "Usage: $0 <service-name>"
	echo ""
	echo "Available services:"
	echo "  pihole      - DNS ad blocker"
	echo "  caddy       - Reverse proxy"
	echo "  linkding    - Bookmark manager"
	echo "  n8n         - Workflow automation"
	echo "  mcp-hub     - MCP Hub"
	echo "  cloudflared - Cloudflare tunnel"
	echo "  mealie      - Recipe manager"
	echo "  readeck     - Reading list"
	echo "  uptime-kuma - Monitoring service"
	echo "  homepage    - Dashboard"
	echo "  plane       - Plane project (alias for plane-pod)"
	echo "  plane-pod   - Plane project management pod (restarts all plane services)"
	echo ""
	echo "Example: $0 n8n"
	exit 1
fi

INPUT_NAME="$1"
SERVICE_NAME="$INPUT_NAME"

if [ "$SERVICE_NAME" = "plane" ]; then
	echo "Mapping 'plane' to 'plane-pod' pod unit"
	SERVICE_NAME="plane-pod"
fi

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

SERVICE_UNIT_OUTPUT=$(systemctl --user list-unit-files --no-legend --no-pager "${SERVICE_NAME}.service" 2>/dev/null || true)
UNIT_SUFFIX=".service"

if [[ -z "$SERVICE_UNIT_OUTPUT" ]]; then
	POD_UNIT_OUTPUT=$(systemctl --user list-unit-files --no-legend --no-pager "${SERVICE_NAME}.pod" 2>/dev/null || true)
	if [[ -n "$POD_UNIT_OUTPUT" ]]; then
		UNIT_SUFFIX=".pod"
	else
		echo "✗ Unknown service: ${INPUT_NAME}"
		exit 1
	fi
fi

UNIT_NAME="${SERVICE_NAME}${UNIT_SUFFIX}"

echo "Restarting $UNIT_NAME..."
if systemctl --user restart "$UNIT_NAME"; then
	echo "✓ ${UNIT_NAME} restarted successfully"

	sleep 2

	echo ""
	echo "Unit status:"
	if systemctl --user is-active "$UNIT_NAME" 2>/dev/null; then
		echo "✓ ${UNIT_NAME} is running"
	else
		echo "✗ ${UNIT_NAME} failed to start"
	fi

	echo ""
	echo "Recent logs (last 10 lines):"
	journalctl --user -u "$UNIT_NAME" -n 10 --no-pager 2>/dev/null || true
else
	echo "✗ Failed to restart $UNIT_NAME"
	echo "Check logs with:"
	echo "  journalctl --user -u ${UNIT_NAME} -f"
	exit 1
fi
