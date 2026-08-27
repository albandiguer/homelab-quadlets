#!/bin/bash
# Remove dangling (untagged) container images to reclaim disk space.
# Intended to run weekly via cron as the podman user.

set -e

export HOME=/home/podman
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# rootless podman refuses to run if the cwd is inaccessible (e.g. /root)
cd "$HOME"

echo "=== podman image prune $(date -Is) ==="
podman image prune -f
echo "Done."
