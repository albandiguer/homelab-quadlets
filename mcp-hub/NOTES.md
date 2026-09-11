# mcp-hub (n8n as an MCP server)

Bridges n8n workflows into the Model Context Protocol, so AI clients can call them as
tools. Part of the MCP chain: `n8n → mcp-hub (MCP/SSE) → mcpo (OpenAPI/REST) → clients`.

| | |
|---|---|
| Image | `docker.io/library/node:latest` running `npx -y mcp-hub` |
| Port | `3002` → container `3000` |
| Config | `mcp-hub/opt/homelab/quadlets/mcp-hub/config.json` (stowed, mounted read-only) |
| Data | `$QUADLET_STORAGE_PATH/mcp-hub/data` |
| Secret | `n8n_api_key` (n8n REST API access) |
| Access | `http://mcp-hub.lab`; SSE endpoint `http://10.0.0.1:3002/mcp` |

## Gotchas

**Use the published port, not the container name.** Container-name DNS on the `podman`
network is unreliable here, so `N8N_API_URL` is set to `http://10.0.0.1:5678` — the
stable, published port.

**SSRF protection blocks private IPs.** `n8n-mcp` refuses to call the private address,
hence `WEBHOOK_SECURITY_MODE=permissive` in the config. Acceptable because the whole
chain is VPN-only; revisit if it is ever exposed publicly.

**`n8n_api_key` must exist.** Create the key in n8n (Settings → API) and store it with
`init-secrets.sh`, otherwise workflow calls fail with auth errors.

## Verify

```bash
curl -s http://10.0.0.1:3002/mcp | head            # SSE endpoint answers
ssh minilab 'podman logs --tail 30 mcp-hub'
```
