#!/bin/bash
# Usage: ./restart.sh <service-name>
ssh hetzner "sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) systemctl --user restart $1.service && sudo -u podman XDG_RUNTIME_DIR=/run/user/\$(id -u podman) journalctl --user -u $1.service -n 20"
