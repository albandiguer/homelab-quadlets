#!/bin/bash
set -e

# Restart Plane pod Quadlet service
# Usage: ./restart.sh

UNIT_NAME="plane-pod.service"

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

if systemctl --user is-active --quiet "$UNIT_NAME"; then
	echo "Restarting ${UNIT_NAME}..."
	systemctl --user restart "$UNIT_NAME"
	echo "✓ ${UNIT_NAME} restarted"
else
	echo "Starting ${UNIT_NAME} for the first time..."
	systemctl --user enable --now "$UNIT_NAME"
	echo "✓ ${UNIT_NAME} started and enabled"
fi

echo ""
echo "Recent logs:"
journalctl --user -u "$UNIT_NAME" -n 10 --no-pager
