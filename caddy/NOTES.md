# Caddy (reverse proxy)

Single entry point for every `*.lab` host. **Host network** so it can own ports 80/443.
TLS is *not* handled here — `auto_https off`, because Cloudflare terminates TLS for the
public hostnames and `.lab` is VPN-only plain HTTP.

| | |
|---|---|
| Image | `docker.io/library/caddy:latest` |
| Ports | `80`, `443`, `2019` (admin API is disabled) |
| Config | repo file `caddy/opt/homelab/quadlets/caddy/Caddyfile` mounted read-only at `/etc/caddy/Caddyfile` |
| Data | `$QUADLET_STORAGE_PATH/caddy/data`, `.../caddy/config` |
| Health | `GET http://localhost:80/health` → `OK` |

## Gotchas

**Rootless publishing means `127.0.0.1`.** Containers on the bridge network publish
their ports on `127.0.0.1` only, so upstreams must be written as `127.0.0.1:<port>`.
Do **not** use `localhost`: inside the container it can resolve to `::1` and the proxy
then fails to connect (this was hit for real; the Caddyfile now pins IPv4).

**Host-network services use their host port.** Pi-hole is reached at `127.0.0.1:8053`
(its web port), Uptime Kuma at `127.0.0.1:3001`.

**Every new service needs a block here**, otherwise DNS resolves but Caddy has no route
and you get a 404/empty reply. Add both names (`.lab` and `.lab.albandiguer.dev`).

**Public routes bypass Caddy for some hosts.** The tunnel ingress maps
`n8n.albandiguer.dev → localhost:80` (through Caddy, so the Caddyfile has a matching
`s http://n8n.albandiguer.dev` block) but `mealie.albandiguer.dev → localhost:9000`
(directly to the container). Check `infra/main.tf` before assuming a public hostname is
routed by Caddy.

## Verify

```bash
curl -sI -H 'Host: linkding.lab' http://10.0.0.1 | head -1   # HTTP/1.1 302 Found
curl -s -o /dev/null -w '%{http_code}\n' http://linkding.lab # 302 (redirect to login)
ssh minilab 'podman logs --tail 20 caddy'                    # config/route errors
```
