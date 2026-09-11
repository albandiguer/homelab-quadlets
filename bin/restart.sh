#!/bin/bash
# Usage: ./restart.sh [service-name ...]
# No arguments: restarts every service listed in bin/services.sh, except INACTIVE_SERVICES.
# Unit names are derived from the repo's quadlet files (plane.pod -> plane-pod.service).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Service list is shared with deploy.sh (single source of truth)
source "$SCRIPT_DIR/services.sh"

# Units for a service, derived from its quadlet files. Pod first, so its member
# containers restart after the pod. Services without quadlet files emit nothing.
units_of() {
	local dir="$SCRIPT_DIR/../$1/.config/containers/systemd" f base
	[ -d "$dir" ] || return 0
	for f in "$dir"/*.pod "$dir"/*.container; do
		[ -e "$f" ] || continue
		base="$(basename "${f%.*}")"
		case "$f" in
		*.pod) printf '%s ' "${base}-pod.service" ;;
		*) printf '%s ' "${base}.service" ;;
		esac
	done
}

# --- Build the unit list ---------------------------------------------------
if [ $# -gt 0 ]; then
	UNITS=""
	for s in "$@"; do UNITS="$UNITS $(units_of "$s")"; done
elif [ -n "$SERVICE" ]; then
	UNITS=" $(units_of "$SERVICE")"
else
	UNITS=""
	for s in "${SERVICES[@]}"; do
		skip=false
		for inactive in "${INACTIVE_SERVICES[@]}"; do
			[ "$s" = "$inactive" ] && skip=true
		done
		[ "$skip" = true ] && continue
		UNITS="$UNITS $(units_of "$s")"
	done
	if [ -z "${UNITS// /}" ]; then
		echo "No services found in bin/services.sh" >&2
		exit 1
	fi
	echo "Restarting:${UNITS}"
fi

# --- Restart on the server (single ssh session; skips units that aren't deployed)
read -r -d '' REMOTE <<'EOF'
for u in __UNITS__; do
	if [ -n "$(systemctl --user list-unit-files "$u" --no-legend 2>/dev/null)" ]; then
		echo "── restarting $u"
		systemctl --user restart "$u" || echo "   ✗ failed: $u"
		journalctl --user -u "$u" -n 20 --no-pager
	else
		echo "── skipping $u (not deployed)"
	fi
done
EOF

# -o RequestTTY=no: the ssh config forces a TTY, which would swallow the script we pipe on stdin
# -n on sudo: fail fast instead of hanging if a password is ever required
ssh -o RequestTTY=no minilab "sudo -n -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u podman)/bus bash -s" <<<"${REMOTE/__UNITS__/$UNITS}"
