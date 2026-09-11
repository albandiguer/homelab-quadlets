# Open WebUI (AI chat)

Chat front-end wired to the MCP chain, so the models can call n8n workflows as tools.

| | |
|---|---|
| Image | `ghcr.io/open-webui/open-webui:main` |
| Port | `3040` → container `8080` |
| Data | `$QUADLET_STORAGE_PATH/open-webui/data` → `/app/backend/data` (SQLite, chats, models) |
| Secret | `openai_api_key` → `OPENAI_API_KEY` |
| Access | `http://openwebui.lab` |

## Gotchas

**First account becomes the admin.** Sign up immediately after the first start; there is
no default user.

**Tools come from mcpo.** If the tool list is empty, check the MCP chain
(`mcp-hub` → `mcpo`) first — Open WebUI only exposes what `http://10.0.0.1:3003/openapi.json`
advertises.

**`openai_api_key` is shared.** The same secret is used by Mealie; rotating it affects
both (restart both containers afterwards).

## Verify

```bash
curl -sI http://openwebui.lab | head -1
ssh minilab 'podman logs --tail 20 open-webui'
```
