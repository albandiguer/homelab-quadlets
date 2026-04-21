#!/bin/bash
# Add a secret to Podman with optional URL encoding
# Usage: ./add-secret.sh <secret-name> <secret-value> [--url-encode]
# Or: echo "secret-value" | ./add-secret.sh <secret-name> [--url-encode]
#
# Examples:
#   ./add-secret.sh my_secret "my-value"
#   ./add-secret.sh db_password "my#pass@word" --url-encode
#   echo -n "my-value" | ./add-secret.sh my_secret

set -e

# Check if running locally or on server
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] || [ "$(hostname)" = "minilab" ]; then
	# Running on server directly
	RUN_MODE="local"
else
	# Running on local machine, will SSH to server
	RUN_MODE="remote"
fi

# Parse arguments
SECRET_NAME=""
SECRET_VALUE=""
URL_ENCODE=false

# If stdin is provided, read from there
if [ -t 0 ]; then
	# No stdin, need name and value as args
	if [ $# -lt 2 ]; then
		echo "Usage: $0 <secret-name> <secret-value> [--url-encode]"
		echo "   or: echo -n 'secret-value' | $0 <secret-name> [--url-encode]"
		exit 1
	fi
	SECRET_NAME="$1"
	SECRET_VALUE="$2"
	shift 2
else
	# Reading from stdin
	if [ $# -lt 1 ]; then
		echo "Usage: $0 <secret-name> [--url-encode]"
		echo "   or: echo -n 'secret-value' | $0 <secret-name> [--url-encode]"
		exit 1
	fi
	SECRET_NAME="$1"
	SECRET_VALUE=$(cat)
	shift 1
fi

# Check for --url-encode flag
while [ $# -gt 0 ]; do
	case "$1" in
		--url-encode)
			URL_ENCODE=true
			shift
			;;
		*)
			echo "Unknown option: $1"
			exit 1
			;;
	esac
done

# URL encode if requested
if [ "$URL_ENCODE" = true ]; then
	# Check if we have Python
	if command -v python3 &> /dev/null; then
		SECRET_VALUE=$(echo -n "$SECRET_VALUE" | python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))')
	elif command -v python &> /dev/null; then
		SECRET_VALUE=$(echo -n "$SECRET_VALUE" | python -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))')
	else
		echo "Error: Python not found, cannot URL encode"
		exit 1
	fi
fi

# Function to create secret
create_secret() {
	local name="$1"
	local value="$2"
	
	# Check if secret already exists
	if podman secret exists "$name" 2>/dev/null; then
		read -p "Secret '$name' already exists. Replace it? (y/N): " confirm
		if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
			echo "Cancelled."
			exit 0
		fi
		podman secret rm "$name"
	fi
	
	# Create the secret (value already has no newline since we used echo -n or read without trailing)
	echo -n "$value" | podman secret create "$name" -
	echo "✓ Created secret: $name"
}

if [ "$RUN_MODE" = "remote" ]; then
	# Running locally - SSH to server and create secret
	echo "Creating secret on minilab server..."
	
	# Escape the secret value for safe SSH transmission
	ESCAPED_VALUE=$(echo -n "$SECRET_VALUE" | base64)
	
	ssh minilab "sudo -u podman -i bash -c '
		export XDG_RUNTIME_DIR=/run/user/\$(id -u)
		
		# Decode the value
		SECRET_VALUE=\$(echo \"$ESCAPED_VALUE\" | base64 -d)
		
		# URL encode if needed
		if [ \"$URL_ENCODE\" = true ]; then
			if command -v python3 &> /dev/null; then
				SECRET_VALUE=\$(echo -n \"\$SECRET_VALUE\" | python3 -c \"import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=''))\")
			else
				echo \"Python3 not found on server\
				exit 1
			fi
		fi
		
		# Check if exists
		if podman secret exists \"$SECRET_NAME\" 2>/dev/null; then
			echo \"Secret already exists, removing...\"
			podman secret rm \"$SECRET_NAME\"
		fi
		
		# Create secret
		echo -n \"\$SECRET_VALUE\" | podman secret create \"$SECRET_NAME\" -
		echo \"Created secret: $SECRET_NAME\"
	'" || {
		echo "Error: Failed to create secret on server"
		exit 1
	}
else
	# Running on server
	export XDG_RUNTIME_DIR="/run/user/$(id -u)"
	create_secret "$SECRET_NAME" "$SECRET_VALUE"
fi
