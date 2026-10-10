# Open WebUI (AI chat)

Chat front-end wired to the MCP chain, so the models can call n8n workflows as tools.

| | |
|---|---|
| Image | `ghcr.io/open-webui/open-webui:main` |
| Port | `3040` → container `8080` |
| Data | `$QUADLET_STORAGE_PATH/open-webui/data` → `/app/backend/data` (SQLite, chats, models) |
| Secret | `openai_api_key` → `OPENAI_API_KEY` |
| Access | `http://openwebui.lab` |

## Web search (SearXNG)

Web search is pointed at the internal `searxng` service. In **Admin Settings → Web
Search** the only field that matters is:

- Engine: `searxng`
- Searxng Query URL: `http://searxng:8080/search`

Use the **base `/search` URL only** — this Open WebUI build appends `q=`, `format=json`
itself and strips anything after `?` (a legacy `?q=<query>` value still works but is
pointless). `open-webui` reaches it by name over `searxng.network`; the default `podman`
network has no DNS, which is why `open-webui` joins that bridge too.

Env vars set the defaults (`ENABLE_WEB_SEARCH`, `WEB_SEARCH_ENGINE`,
`SEARXNG_QUERY_URL`); a value saved in the UI wins over them.

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
