# n8n (workflow automation)

| | |
|---|---|
| Image | `docker.n8n.io/n8nio/n8n:latest` |
| Port | `5678` (published on `127.0.0.1`) |
| Data | `$QUADLET_STORAGE_PATH/n8n/data` → `/home/node/.n8n` (SQLite `database.sqlite` + credentials) |
| Secrets | `n8n_basic_auth_user` / `n8n_basic_auth_password`, plus `n8n_api_key` (used by mcp-hub) |
| Access | `http://n8n.lab` (VPN) and `https://n8n.albandiguer.dev` (public, via tunnel → Caddy) |

## Gotchas

**Volume ownership.** The container runs as UID 1000, which maps to host UID
**100999** under rootless Podman. If n8n cannot write its database:

```bash
ssh root@10.0.0.1 'chown -R 100999:100999 /mnt/minilab-data/n8n/data'
```

**Credentials are only as safe as the database.** No `N8N_ENCRYPTION_KEY` is set, so
n8n keeps its encryption key inside its own database — API credentials stay readable as
long as `database.sqlite` survives. Losing the *secret* only costs you the login gate;
losing the *volume* loses everything.

**Basic-auth env vars are legacy.** `N8N_BASIC_AUTH_*` predates n8n's own user
management (1.x). Treat it as the instance login gate, and if login behaves oddly check
whether n8n is actually using its internal user accounts.

**Webhooks need a public hostname.** Anything called from the internet must go through
the tunnel route (`n8n.albandiguer.dev`), and the workflow has to be active.

**Webhook + schedule in one workflow.** n8n refuses to combine a webhook trigger and a
schedule trigger (the "Respond to Webhook" node becomes unusable). For a scheduled run
create a second, schedule-only workflow that calls the first.

## Verify

```bash
curl -sI http://n8n.lab | head -1
ssh minilab 'podman exec n8n curl -sf http://localhost:5678/healthz'   # {"status":"ok"}
```
