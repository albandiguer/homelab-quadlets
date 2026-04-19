#!/bin/bash
# Usage: ./restart.sh <service-name>

SERVICE=${1:-$SERVICE}

if [ -z "$SERVICE" ]; then
	echo "Usage: ./restart.sh <service-name>"
	echo "Or set SERVICE environment variable"
	exit 1
fi

ssh minilab "sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) systemctl --user restart ${SERVICE}.service && sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) journalctl --user -u ${SERVICE}.service -n 20"
