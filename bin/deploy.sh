#!/bin/bash
set -e

# Script to deploy Quadlet containers to the homelab server

# Configuration
SERVER_IP="10.0.0.1"
SERVICES=(pihole caddy linkding n8n mcp-hub cloudflared mealie)

# Find directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUADLETS_DIR="$(dirname "$SCRIPT_DIR")"
INFRA_DIR="$(dirname "$QUADLETS_DIR")/infra"

# Helper: Run SSH command on server
ssh_exec() {
	ssh root@$SERVER_IP "$@"
}

# Helper: Run SSH command as podman user
ssh_podman() {
	ssh_exec "sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) $*"
}

# Helper: Load Bitwarden item credentials
load_bw_creds() {
	local item_name=$1
	local var_prefix=$2

	if [ -z "$BW_SESSION" ]; then
		return 1
	fi

	local item
	item=$(bw get item "$item_name" 2>&1 >/dev/null)
	local exit_code=$?

	if [ $exit_code -eq 0 ]; then
		item=$(bw get item "$item_name" 2>/dev/null)
		export "${var_prefix}_USER=$(echo "$item" | jq -r '.login.username')"
		export "${var_prefix}_PASSWORD=$(echo "$item" | jq -r '.login.password')"
		echo "  ✓ $item_name credentials loaded" >&2
		return 0
	fi
	return 1
}

# Load credentials and tokens needed for deployment
load_credentials() {
	echo "Loading credentials and tokens..." >&2

	# Get Cloudflared tunnel token from Terraform
	if [ -f "$INFRA_DIR/terraform.tfstate" ]; then
		export CLOUDFLARED_TUNNEL_TOKEN=$(cd "$INFRA_DIR" && terraform output -json cloudflare_tunnel 2>/dev/null | jq -r '.tunnel_token' 2>/dev/null)
		if [ -n "$CLOUDFLARED_TUNNEL_TOKEN" ] && [ "$CLOUDFLARED_TUNNEL_TOKEN" != "null" ]; then
			echo "  ✓ Cloudflared tunnel token loaded" >&2
		else
			echo "  ✗ Failed to load Cloudflared tunnel token" >&2
			exit 1
		fi
	else
		echo "  ✗ Terraform state not found" >&2
		exit 1
	fi

	# Fetch service credentials from Bitwarden
	if ! command -v bw &>/dev/null; then
		echo "  ✗ Bitwarden CLI not found. Install with: brew install bitwarden-cli" >&2
		exit 1
	fi

	# Check if Bitwarden is unlocked by testing status
	local bw_status
	bw_status=$(bw status 2>&1)
	if ! echo "$bw_status" | grep -q '"status":"unlocked"'; then
		echo "" >&2
		echo "  ✗ Bitwarden is locked. Please unlock first:" >&2
		echo "     export BW_SESSION=\$(bw unlock --raw)" >&2
		echo "" >&2
		exit 1
	fi

	# Load credentials and fail if any are missing
	if ! load_bw_creds "n8n.lab.albandiguer.dev" "N8N_BASIC_AUTH"; then
		echo "  ✗ Failed to load n8n credentials" >&2
		exit 1
	fi

	if ! load_bw_creds "linkding.lab.albandiguer.dev" "LINKDING_SUPERUSER"; then
		echo "  ✗ Failed to load Linkding credentials" >&2
		exit 1
	fi

	# Mealie credentials
	local mealie_item
	mealie_item=$(bw get item mealie.lab 2>&1)
	if [ $? -eq 0 ]; then
		export MEALIE_DEFAULT_EMAIL=$(echo "$mealie_item" | jq -r '.login.username')
		export MEALIE_DEFAULT_PASSWORD=$(echo "$mealie_item" | jq -r '.login.password')
		echo "  ✓ mealie.lab credentials loaded" >&2
	else
		echo "  ✗ Failed to load Mealie credentials" >&2
		exit 1
	fi

	# Pi-hole only uses password
	local pihole_item
	pihole_item=$(bw get item pihole.lab.albandiguer.dev 2>&1)
	if [ $? -eq 0 ]; then
		export PIHOLE_WEBPASSWORD=$(echo "$pihole_item" | jq -r '.login.password')
		echo "  ✓ Pi-hole credentials loaded" >&2
	else
		echo "  ✗ Failed to load Pi-hole credentials" >&2
		exit 1
	fi
}

# Create remote directories
setup_directories() {
	echo "Setting up remote directories..."
	local service_dirs=$(printf "/opt/homelab/quadlets/%s," "${SERVICES[@]}" | sed 's/,$//')
	ssh_exec "mkdir -p {${service_dirs}} && chown -R podman:podman /opt/homelab"
	ssh_podman "mkdir -p /home/podman/.config/containers/systemd"
}

# Create and configure volume directories
setup_volumes() {
	echo "Setting up volume directories..."
	ssh_exec <<'EOF'
		# Create directories for each service
		mkdir -p /mnt/HC_Volume_103621273/{n8n,pihole,caddy,linkding,mcp-hub,cloudflared,mealie}/{data,etc,config,dnsmasq.d}

		# n8n runs as UID 1000, maps to host UID 100999 in rootless podman
		chown -R 100999:100999 /mnt/HC_Volume_103621273/n8n/data

		# Other services owned by podman user
		chown -R podman:podman /mnt/HC_Volume_103621273/{pihole,caddy,linkding,mcp-hub,cloudflared,mealie}
EOF
}

# Deploy Quadlet container definitions
deploy_quadlets() {
	echo "Deploying Quadlet container definitions..."
	for file in "$QUADLETS_DIR"/*.container; do
		[ -f "$file" ] && scp "$file" root@$SERVER_IP:/tmp/
	done
	ssh_exec 'chown podman:podman /tmp/*.container && mv /tmp/*.container /home/podman/.config/containers/systemd/'
}

# Process .env files with variable substitution
process_env_files() {
	echo "Processing .env files..."
	local temp_dir=$(mktemp -d)
	trap "rm -rf $temp_dir" EXIT

	for service in "${SERVICES[@]}"; do
		if [ -f "$QUADLETS_DIR/$service/.env" ]; then
			echo "  Substituting variables in $service/.env"
			envsubst <"$QUADLETS_DIR/$service/.env" >"$temp_dir/$service.env"
			scp "$temp_dir/$service.env" root@$SERVER_IP:/opt/homelab/quadlets/$service/.env
		fi
	done

	ssh_exec "chown -R podman:podman /opt/homelab/quadlets/"
}

# Deploy service-specific config files
deploy_service_configs() {
	echo "Deploying service configurations..."

	# Deploy Caddyfile
	if [ -f "$QUADLETS_DIR/caddy/Caddyfile" ]; then
		scp "$QUADLETS_DIR/caddy/Caddyfile" root@$SERVER_IP:/opt/homelab/quadlets/caddy/
	fi

	# Deploy MCP-Hub config
	if [ -f "$QUADLETS_DIR/mcp-hub/config.json" ]; then
		scp "$QUADLETS_DIR/mcp-hub/config.json" root@$SERVER_IP:/opt/homelab/quadlets/mcp-hub/
	fi

	# Copy other service files (excluding .env which was already processed)
	for service in "${SERVICES[@]}"; do
		if [ -d "$QUADLETS_DIR/$service" ]; then
			for file in "$QUADLETS_DIR/$service"/*; do
				if [ -f "$file" ] && [ "$(basename "$file")" != ".env" ]; then
					scp "$file" root@$SERVER_IP:/opt/homelab/quadlets/$service/
				fi
			done
		fi
	done

	ssh_exec "chown -R podman:podman /opt/homelab/quadlets/"
}

# Start services via systemd
start_services() {
	echo "Starting container services..."

	ssh_podman "systemctl --user daemon-reload"

	for service in "${SERVICES[@]}"; do
		ssh_podman "systemctl --user start $service.service"
	done
}

# Check service status
check_status() {
	echo ""
	echo "Service Status:"

	for service in "${SERVICES[@]}"; do
		# Get display name
		case "$service" in
		pihole) display_name="Pi-hole" ;;
		caddy) display_name="Caddy" ;;
		linkding) display_name="Linkding" ;;
		n8n) display_name="n8n" ;;
		mcp-hub) display_name="MCP-Hub" ;;
		cloudflared) display_name="Cloudflared" ;;
		mealie) display_name="Mealie" ;;
		*) display_name="$service" ;;
		esac

		if ssh_podman "systemctl --user is-active $service.service" &>/dev/null; then
			echo "  ✓ $display_name is running"
		else
			echo "  ✗ $display_name failed to start"
		fi
	done

	echo ""
	echo "Container Status:"
	ssh_exec 'su - podman -c "XDG_RUNTIME_DIR=/run/user/\$(id -u) podman ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\""'
}

# Print deployment summary
print_summary() {
	cat <<EOF

========================================
Deployment Complete!
========================================

Services (via VPN):
  - Pi-hole Admin: http://pihole.lab/admin
  - Linkding: http://linkding.lab
  - n8n: http://n8n.lab
  - MCP-Hub: http://mcp-hub.lab
  - Mealie: http://mealie.lab

Public URLs:
  - n8n Webhooks: https://n8n.albandiguer.dev

Check logs:
  ssh root@$SERVER_IP 'sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) journalctl --user -u <service>.service -f'

========================================
EOF
}

# Main deployment flow
main() {
	echo "Deploying Quadlet containers to $SERVER_IP..."

	load_credentials
	setup_directories
	setup_volumes
	deploy_quadlets
	process_env_files
	deploy_service_configs
	start_services
	check_status
	print_summary
}

main
