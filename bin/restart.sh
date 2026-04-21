#!/bin/bash
# Usage: ./restart.sh <service-name>
# Maps directory names to actual systemd service names (e.g., plane -> plane-pod)

SERVICE=${1:-$SERVICE}

if [ -z "$SERVICE" ]; then
	echo "Usage: ./restart.sh <service-name>"
	echo "Or set SERVICE environment variable"
	exit 1
fi

# Map directory names to actual systemd service names
case "$SERVICE" in
	plane) SERVICE_UNIT="plane-pod" ;;
	*) SERVICE_UNIT="$SERVICE" ;;
esac

ssh minilab "sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) systemctl --user restart ${SERVICE_UNIT}.service && sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) journalctl --user -u ${SERVICE_UNIT}.service -n 20"
