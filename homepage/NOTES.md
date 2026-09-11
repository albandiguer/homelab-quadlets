# Homepage (dashboard) — INACTIVE

A service dashboard that aggregates links to everything else.

| | |
|---|---|
| Image | `ghcr.io/gethomepage/homepage:latest` |
| Port | `3030` → container `3000` |
| Data | `$QUADLET_STORAGE_PATH/homepage` → `/app/config` |
| Mounts | podman socket (`%t/podman/podman.sock`, read-only) for container widgets |

**Inactive on purpose**: listed in `INACTIVE_SERVICES` in `bin/services.sh`, so
`deploy.sh` stops/disables it and deletes its stow symlinks on every deploy.

To bring it back: remove `homepage` from `INACTIVE_SERVICES`, then
`./bin/deploy-local.sh homepage`.

Note the podman-socket mount: running it grants the container read access to the host's
container API, so re-enable it knowingly.
