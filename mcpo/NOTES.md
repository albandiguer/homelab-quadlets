# mcpo (MCP → OpenAPI proxy)

Turns an MCP server (SSE) into a plain REST/OpenAPI service, for clients that cannot
speak MCP — this is how Open WebUI talks to the n8n workflows.

| | |
|---|---|
| Image | `ghcr.io/open-webui/mcpo:main` |
| Port | `3003` → container `8000` |
| Config | `mcpo/opt/homelab/quadlets/mcpo/config.json` |
| Depends on | n8n + mcp-hub (workflow calls fail while either is down) |
| Access | `http://mcpo.lab`; REST base `http://10.0.0.1:3003` |

**Wart:** unlike every other service, this one mounts its config from the *repo checkout*
(`/home/podman/homelab-quadlets/mcpo/opt/...`) instead of the stowed path
(`/home/podman/opt/homelab/quadlets/mcpo/...`). It works, but it breaks the convention —
worth normalising next time the file is touched.

## Verify

```bash
curl -s http://10.0.0.1:3003/openapi.json | jq '.paths | keys'   # exposed tools
```

Full-chain smoke test (a real workflow call through mcp-hub + n8n):

```bash
curl -X POST http://10.0.0.1:3003/n8n/n8n_mcp__n8n_test_workflow \
  -H 'Content-Type: application/json' \
  -d '{"workflowId": "Y15GXGuN5klDxIk4", "triggerType": "webhook"}'
```

## Adding an MCP server to the chain

1. Add the server to `mcp-hub/opt/homelab/quadlets/mcp-hub/config.json` → `servers`
2. If it should be reachable over REST, reference it in
   `mcpo/opt/homelab/quadlets/mcpo/config.json` → `mcpServers`
3. Redeploy both: `./bin/deploy-local.sh mcp-hub mcpo`
