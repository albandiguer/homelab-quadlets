#!/bin/bash
set -e

# Restart Plane pod Quadlet service
# Usage: ./restart.sh

UNIT_NAME="plane-pod.pod"

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Check if unit exists, fallback to .pod
# if ! systemctl --user list-unit-files "$UNIT_NAME" >/dev/null 2>&1; then
# 	UNIT_NAME="plane-pod.pod"
# fi

echo "Restarting ${UNIT_NAME}..."
systemctl --user restart "$UNIT_NAME"
echo "✓ ${UNIT_NAME} restarted"

echo ""
echo "Recent logs:"
journalctl --user -u "$UNIT_NAME" -n 10 --no-pager
