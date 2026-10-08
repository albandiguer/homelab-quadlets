# SearXNG (metasearch engine)

|         |                                                                     |
| ------- | ------------------------------------------------------------------- |
| Image   | `docker.io/searxng/searxng:latest`                                  |
| Port    | `8080` — **not published**, internal to the `podman` network only   |
| Data    | none — config is a read-only mount, cache is ephemeral              |
| Secrets | `searxng_secret` (`SEARXNG_SECRET`, `openssl rand -hex 32`)         |
| Access  | `http://searxng:8080` from other containers on the `podman` network |

Internal search backend for n8n's web search / AI-agent tool. n8n points at it with
`SEARXNG_URL=http://searxng:8080` and resolves the name over the shared `podman`
network — no pod, no published port.

## Gotchas

**The JSON format must be enabled.** Upstream SearXNG only serves HTML by default;
n8n's search calls the JSON API. `settings.yml` sets `search.formats: [html, json]`.
Remove that and n8n gets HTML back and fails to parse.

**`SEARXNG_SECRET` is mandatory.** The image exits if it is unset, so
`bin/init-secrets.sh` has to run before the first start.

**Deliberately unpublished.** The JSON API is unauthenticated; do not add a
`PublishPort`. Reaching it from the host means `podman exec n8n ...`, not a host port.

**Memory scales with concurrency.** ~150 MB idle, ~250-400 MB during a search, no
persistent storage to grow.

**Some engines return 429/CAPTCHA.** Upstream engines (DuckDuckGo, Brave) rate-limit
shared IPs; the log shows warnings but results still arrive from the other engines.

## Verify

```bash
ssh minilab 'podman exec n8n curl -sf "http://searxng:8080/search?q=test&format=json" | head -c 200'
# expect JSON, not HTML
ssh minilab 'systemctl --user status searxng.service --no-pager'
```

In n8n, the web-search tool then works with no further configuration.
