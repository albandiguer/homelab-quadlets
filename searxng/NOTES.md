# SearXNG (metasearch engine)

|         |                                                                     |
| ------- | ------------------------------------------------------------------- |
| Image   | `docker.io/searxng/searxng:latest`                                  |
| Port    | `8080` — published on `127.0.0.1` only; `n8n` uses the `searxng.network` bridge |
| Data    | none — config is a read-only mount, cache is ephemeral              |
| Secrets | `searxng_secret` (`SEARXNG_SECRET`, `openssl rand -hex 32`)         |
| Access  | `http://searxng:8080` reached by `n8n` over the `searxng.network` bridge |

Internal search backend for n8n's web search / AI-agent tool. n8n points at it with
`SEARXNG_URL=http://searxng:8080` and resolves the name over `searxng.network` — no
pod, no LAN exposure.

## Why a dedicated network

The default `podman` network has container-name DNS **disabled**, so `searxng:8080`
does not resolve there. `searxng.network` is a small bridge with DNS enabled (Podman
default) that only `searxng` and `n8n` join; `n8n` stays on the `podman` network as
well.

## Gotchas

**The JSON format must be enabled.** Upstream SearXNG only serves HTML by default;
n8n's search calls the JSON API. `settings.yml` sets `search.formats: [html, json]`.
Remove that and n8n gets HTML back and fails to parse.

**`SEARXNG_SECRET` is mandatory.** The image exits if it is unset, so
`bin/init-secrets.sh` has to run before the first start.

**Loopback publish only.** The JSON API is unauthenticated, so the one published port
is bound to `127.0.0.1` — never the LAN — purely so Uptime Kuma (host network) can
probe `/healthz`. Keep the `127.0.0.1:` prefix; `n8n` uses the bridge name, not this
port.

**Memory scales with concurrency.** ~150 MB idle, ~250-400 MB during a search, no
persistent storage to grow.

**Some engines return 429/CAPTCHA.** Upstream engines (DuckDuckGo, Brave) rate-limit
shared IPs; the log shows warnings but results still arrive from the other engines.

## Verify

```bash
ssh minilab 'podman exec n8n curl -sf "http://searxng:8080/search?q=test&format=json" | head -c 200'
# expect JSON, not HTML
ssh minilab 'curl -sf http://127.0.0.1:8080/healthz'   # what Uptime Kuma probes
ssh minilab 'systemctl --user status searxng.service --no-pager'
```

## Monitoring

Uptime Kuma (host network, `http://uptime.lab`) monitors
`http://127.0.0.1:8080/healthz` as an HTTP(s) keyword monitor (`OK`). Monitors live in
Kuma's own SQLite, so adding one is a UI action, not a config change in this repo.

In n8n, the web-search tool then works with no further configuration.
