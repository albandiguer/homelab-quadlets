# Single source of truth for the services this repo manages.
# Sourced by bin/deploy.sh (on the server) and bin/restart.sh (locally).
# Keep bash-array syntax: no parser dependency, works on the server as-is.

SERVICES=(
	caddy
	cloudflared
	config
	discourse
	headroom
	homepage
	linkding
	mcp-hub
	mcpo
	mealie
	n8n
	open-webui
	pihole
	plane
	readeck
	searxng
	uptime-kuma
)

# Deployed-to-disk but stopped/disabled (deploy.sh removes them, restart.sh skips them)
INACTIVE_SERVICES=(
	homepage
)

# Map a service directory name to its systemd unit (exceptions only).
# Accepts "plane" or "plane.service" and always returns a full unit name.
unit_of() {
	case "${1%.service}" in
	plane) echo "plane-pod.service" ;;
	*) echo "${1%.service}.service" ;;
	esac
}
