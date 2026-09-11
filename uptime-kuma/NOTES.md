# Uptime Kuma (monitoring)

| | |
|---|---|
| Image | `docker.io/louislam/uptime-kuma:latest` |
| Network | **host** — listens on `3001` directly |
| Data | `$QUADLET_STORAGE_PATH/uptime-kuma` → `/app/data` (SQLite) |
| Access | `http://uptime.lab` (Caddy → `127.0.0.1:3001`) |

Because it uses host networking, monitors can reach anything bound to the host —
including the VPN-only admin ports — without going back out through Caddy.

## Verify

```bash
curl -sI http://uptime.lab | head -1
ssh minilab 'podman logs --tail 20 uptime-kuma'
```
