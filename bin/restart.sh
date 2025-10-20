#!/bin/bash
set -e

# Restart Quadlet service or pod
# Usage: ./restart.sh <service-name>
# Example: ./restart.sh plane-pod

if [ -z "$1" ]; then
	echo "Error: Service name required"
	echo "Usage: $0 <service-name>"
	echo "Example: $0 plane-pod"
	exit 1
fi

SERVICE_NAME="$1"
# Add .service suffix if not present
if [[ ! "$SERVICE_NAME" =~ \.service$ ]]; then
	UNIT_NAME="${SERVICE_NAME}.service"
else
	UNIT_NAME="$SERVICE_NAME"
fi

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Check if service exists
if ! systemctl --user list-unit-files "$UNIT_NAME" >/dev/null 2>&1; then
	echo "Error: Service '$UNIT_NAME' not found"
	exit 1
fi

if systemctl --user is-active --quiet "$UNIT_NAME"; then
	echo "Restarting ${UNIT_NAME}..."
	systemctl --user restart "$UNIT_NAME"
	echo "✓ ${UNIT_NAME} restarted"
else
	echo "Starting ${UNIT_NAME}..."
	systemctl --user start "$UNIT_NAME"
	echo "✓ ${UNIT_NAME} started"
fi

echo ""
echo "Recent logs:"
journalctl --user -u "$UNIT_NAME" -n 10 --no-pager
