#!/bin/bash
set -e

# Initialize Podman secrets interactively or via command line
# Prompts for each secret value and creates them in Podman

# URL encode a string using Python
url_encode() {
	local value="$1"
	if command -v python3 &> /dev/null; then
		echo -n "$value" | python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""), end="")'
	elif command -v python &> /dev/null; then
		echo -n "$value" | python -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""), end="")'
	else
		echo "Error: Python not found, cannot URL encode" >&2
		return 1
	fi
}

# Helper: Create or update a secret from stdin
create_secret() {
	local secret_name=$1
	local prompt_text=$2
	local url_encode_flag=$3
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

	# URL encode if requested
	if [ "$url_encode_flag" = "true" ]; then
		secret_value=$(url_encode "$secret_value")
		echo "  ℹ URL-encoded value"
	fi

	echo -n "$secret_value" | podman secret create "$secret_name" -
	echo "  ✓ Created secret: $secret_name"
}

# Helper: Create a Plane database URL with URL-encoded password
create_plane_db_url() {
	local secret_name="plane_database_url"
	local prompt_password="Plane - Database password (will be URL-encoded automatically)"
	local db_password

	# Check if secret exists
	if podman secret exists "$secret_name" 2>/dev/null; then
		read -p "Secret '$secret_name' already exists. Update it? (y/N): " update
		if [[ ! "$update" =~ ^[Yy]$ ]]; then
			echo "  ⊘ Skipping $secret_name"
			return 0
		fi
		podman secret rm "$secret_name"
	fi

	# Prompt for just the password
	read -sp "$prompt_password: " db_password
	echo

	if [ -z "$db_password" ]; then
		echo "  ✗ Empty password, skipping $secret_name"
		return 1
	fi

	# URL encode the password
	local encoded_password
	encoded_password=$(url_encode "$db_password")
	echo "  ℹ URL-encoded password"

	# Build the full database URL
	local db_url="postgresql://plane:${encoded_password}@plane:5432/plane"
	echo -n "$db_url" | podman secret create "$secret_name" -
	echo "  ✓ Created secret: $secret_name"
}

# Helper: Create a Plane AMQP URL with URL-encoded password
create_plane_amqp_url() {
	local secret_name="plane_mq_amqp_url"
	local prompt_password="Plane - RabbitMQ password (will be URL-encoded automatically)"
	local mq_password

	# Check if secret exists
	if podman secret exists "$secret_name" 2>/dev/null; then
		read -p "Secret '$secret_name' already exists. Update it? (y/N): " update
		if [[ ! "$update" =~ ^[Yy]$ ]]; then
			echo "  ⊘ Skipping $secret_name"
			return 0
		fi
		podman secret rm "$secret_name"
	fi

	# Prompt for just the password
	read -sp "$prompt_password: " mq_password
	echo

	if [ -z "$mq_password" ]; then
		echo "  ✗ Empty password, skipping $secret_name"
		return 1
	fi

	# URL encode the password
	local encoded_password
	encoded_password=$(url_encode "$mq_password")
	echo "  ℹ URL-encoded password"

	# Build the full AMQP URL
	local amqp_url="amqp://plane:${encoded_password}@plane:5672/plane"
	echo -n "$amqp_url" | podman secret create "$secret_name" -
	echo "  ✓ Created secret: $secret_name"
}

# n8n secrets
echo "=== n8n Credentials ==="
create_secret "n8n_basic_auth_user" "n8n basic auth username"
create_secret "n8n_basic_auth_password" "n8n basic auth password"
create_secret "n8n_api_key" "n8n API key"
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

# Plane
echo "=== Plane.so Credentials ==="
create_secret "plane_db_password" "Plane - PostgreSQL password (also used for DATABASE_URL)"
create_plane_db_url
create_secret "plane_secret_key" "Plane - Application secret key (generate with: openssl rand -hex 32)"
create_secret "plane_minio_root_password" "Plane - MinIO root password"
create_secret "plane_mq_password" "Plane - RabbitMQ password (also used for AMQP_URL)"
create_plane_amqp_url
create_secret "plane_live_server_secret_key" "Plane - Live server secret key (generate with: openssl rand -hex 32)"
echo ""

# OpenAI - transveral usage (mealie and others)
echo "=== Misc Credentials ==="
create_secret "openai_api_key" "openai api key"
echo ""

echo "✓ All secrets initialized successfully!"
echo ""
echo "You can verify secrets with:"
echo "  podman secret ls"
echo ""
echo "To view a secret (for debugging):"
echo "  podman secret inspect <secret-name>"
