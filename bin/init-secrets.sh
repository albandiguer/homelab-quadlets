#!/bin/bash
set -e

# Initialize Podman secrets interactively
# Prompts for each secret value and creates them in Podman

echo "Initializing Podman secrets..."
echo ""

# Helper: Create or update a secret from stdin
create_secret() {
	local secret_name=$1
	local prompt_text=$2
	local secret_value

	# Check if secret exists
	if podman secret exists "$secret_name" 2>/dev/null; then
		read -p "Secret '$secret_name' already exists. Update it? (y/N): " update
		if [[ ! "$update" =~ ^[Yy]$ ]]; then
			echo "  ⊘ Skipping $secret_name"
			return 0
		fi
		podman secret rm "$secret_name"
	fi

	# Prompt for secret value
	read -sp "$prompt_text: " secret_value
	echo

	if [ -z "$secret_value" ]; then
		echo "  ✗ Empty value, skipping $secret_name"
		return 1
	fi

	echo -n "$secret_value" | podman secret create "$secret_name" -
	echo "  ✓ Created secret: $secret_name"
}

# n8n secrets
echo "=== n8n Credentials ==="
create_secret "n8n_basic_auth_user" "n8n basic auth username"
create_secret "n8n_basic_auth_password" "n8n basic auth password"
echo ""

# Linkding secrets
echo "=== Linkding Credentials ==="
create_secret "linkding_superuser_name" "Linkding superuser name"
create_secret "linkding_superuser_password" "Linkding superuser password"
echo ""

# Mealie secrets
echo "=== Mealie Credentials ==="
create_secret "mealie_default_email" "Mealie default email"
create_secret "mealie_default_password" "Mealie default password"
echo ""

# Pi-hole secret
echo "=== Pi-hole Credentials ==="
create_secret "pihole_webpassword" "Pi-hole web password"
echo ""

# Cloudflared secret
echo "=== Cloudflare Tunnel ==="
create_secret "cloudflared_tunnel_token" "Cloudflare tunnel token"
echo ""

# MCP Hub secrets
echo "=== MCP Hub API Keys ==="
create_secret "context7_api_key" "Context7 API key"
echo ""

echo "✓ All secrets initialized successfully!"
echo ""
echo "You can verify secrets with:"
echo "  podman secret ls"
echo ""
echo "To view a secret (for debugging):"
echo "  podman secret inspect <secret-name>"
