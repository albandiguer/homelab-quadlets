#!/bin/bash
set -e

# Deploy quadlet services from Git repository using GNU Stow
# This script should be run on the server (as podman user)
# Usage: ssh minilab 'sudo -u podman /home/podman/homelab-quadlets/bin/deploy.sh'

SERVICES=(
	caddy
	cloudflared
	config
	homepage
	linkding
	mealie
	n8n
	open-webui
	pihole
	plane-pod
	readeck
	uptime-kuma
)
INACTIVE_SERVICES=(
	homepage
	uptime-kuma
	mcp-hub
)
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
echo "Removing inactive services..."

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

for service in "${INACTIVE_SERVICES[@]}"; do
	if [ ! -d "$service" ]; then
		continue
	fi

	echo "  Stopping and disabling $service..."
	# Stop service if running
	systemctl --user stop "${service}.service" 2>/dev/null || true
	# Disable service if enabled
	systemctl --user disable "${service}.service" 2>/dev/null || true

	echo "  Unstowing $service..."
	stow --delete --target="$HOME" "$service" 2>/dev/null || true
done

systemctl --user daemon-reload 2>/dev/null || true

echo ""
echo "Deploying quadlet services with GNU Stow..."

for service in "${SERVICES[@]}"; do
	# Skip if in inactive list
	skip=false
	for inactive in "${INACTIVE_SERVICES[@]}"; do
		if [ "$service" = "$inactive" ]; then
			skip=true
			break
		fi
	done
	if [ "$skip" = true ]; then
		echo "  ⊘ Service '$service' is inactive, skipping"
		continue
	fi
	if [ ! -d "$service" ]; then
		echo "  ⊘ Service '$service' not found, skipping"
		continue
	fi

	echo "  Installing $service..."
	stow --restow --target="$HOME" "$service"

	# Create volume directories for this service
	container_file="$service/.config/containers/systemd/${service%.pod}.container"
	if [ -f "$container_file" ]; then
		# Get storage path from environment or use default
		storage_path="${QUADLET_STORAGE_PATH:-/mnt/minilab-data}"

		# Extract volume host paths and create directories
		# Only create directories for paths containing QUADLET_STORAGE_PATH (data volumes)
		# Skip bind mounts that reference files or absolute paths outside storage
		grep -E '^Volume=' "$container_file" 2>/dev/null | while IFS= read -r line; do
			# Extract path between Volume= and the colon
			host_path=$(echo "$line" | sed -n 's/^Volume=\([^:]*\):.*/\1/p')
			# Only process if it contains the storage path variable
			if echo "$host_path" | grep -q '\${QUADLET_STORAGE_PATH}'; then
				# Expand the variable
				host_path=$(echo "$host_path" | sed "s|\\\${QUADLET_STORAGE_PATH}|$storage_path|g")
				if [ -n "$host_path" ] && [ ! -d "$host_path" ]; then
					echo "    Creating volume directory: $host_path"
					mkdir -p "$host_path"
				fi
			fi
		done
	fi
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
