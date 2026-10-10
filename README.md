# homelab-quadlets

Rootless Podman containers on Fedora, defined as [Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
units (`<service>.container` → `<service>.service`) and deployed with
[GNU Stow](https://www.gnu.org/software/stow/manual/stow.html). Secrets come from
Podman secrets, persistence from a Hetzner block volume.

Owned by the [`homelab`](https://github.com/albandiguer/homelab) repo as a submodule.

## Layout

```
<service>/
  .config/containers/systemd/<service>.container   # quadlet definition -> systemd unit
  opt/homelab/quadlets/<service>/                  # config files (stowed to $HOME/opt/...)
  NOTES.md                                         # service-specific gotchas
config/.config/environment.d/quadlets.conf         # QUADLET_STORAGE_PATH=/mnt/minilab-data
bin/
  services.sh        # single source of truth: SERVICES + INACTIVE_SERVICES
  deploy.sh          # server-side: git pull, stow, create volume dirs, daemon-reload
  deploy-local.sh    # local: git push minilab + deploy.sh (+ restart named services)
  restart.sh         # restart one/many services, or everything (no args)
  init-secrets.sh    # create/update Podman secrets (interactive)
  prune-images.sh    # clean dangling images
```

`deploy.sh` stows two things per service: the unit into `~/.config/containers/systemd/`
and the config directory into `~/opt/homelab/quadlets/<service>/` — which is the path
containers mount (see the mcpo exception in `mcpo/NOTES.md`).

## Services

| Service        | Port                   | Access                                 | Secrets                              | Notes                                 |
| -------------- | ---------------------- | -------------------------------------- | ------------------------------------ | ------------------------------------- |
| 🛡️ pihole      | 53 (DNS), 8053 (admin) | `pihole.lab`                           | `pihole_webpassword`                 | [NOTES](pihole/NOTES.md)              |
| 🔀 caddy       | 80                     | host network                           | —                                    | [NOTES](caddy/NOTES.md)               |
| ☁️ cloudflared | —                      | outbound tunnel                        | `cloudflared_tunnel_token`           | [NOTES](cloudflared/NOTES.md)         |
| ⚡ n8n         | 5678                   | `n8n.lab`, `n8n.albandiguer.dev`       | `n8n_basic_auth_*`                   | [NOTES](n8n/NOTES.md)                 |
| 🔎 searxng     | 8080 (loopback)        | internal (n8n only)                    | `searxng_secret`                     | [NOTES](searxng/NOTES.md)             |
| 🔖 linkding    | 9090                   | `linkding.lab`                         | `linkding_superuser_*`               | [NOTES](linkding/NOTES.md)            |
| 🍽️ mealie      | 9000                   | `mealie.lab`, `mealie.albandiguer.dev` | `mealie_default_*`, `openai_api_key` | [NOTES](mealie/NOTES.md)              |
| 📖 readeck     | 8000                   | `readeck.lab`                          | —                                    | [NOTES](readeck/NOTES.md)             |
| 🤖 open-webui  | 3040                   | `openwebui.lab`                        | `openai_api_key`                     | [NOTES](open-webui/NOTES.md)          |
| 🗜️ headroom    | 8787                   | `headroom.lab`                         | —                                    | [NOTES](headroom/NOTES.md)            |
| 💬 discourse   | 8081                   | `discourse.lab`                        | `discourse_db_password`              | [NOTES](discourse/NOTES.md) — locally built (`.build`) |
| 🔌 mcp-hub     | 3002                   | `mcp-hub.lab`                          | `n8n_api_key`                        | [NOTES](mcp-hub/NOTES.md)             |
| 🧩 mcpo        | 3003                   | `mcpo.lab`                             | —                                    | [NOTES](mcpo/NOTES.md)                |
| 📊 uptime-kuma | 3001                   | `uptime.lab`                           | —                                    | [NOTES](uptime-kuma/NOTES.md)         |
| 📐 plane       | 8085 (+ MinIO 9001)    | `plane.lab`, `plane-minio.lab`         | `plane_*` (7 secrets)                | [NOTES](plane/NOTES.md)               |
| 🏠 homepage    | 3030                   | `homepage.lab`                         | —                                    | [NOTES](homepage/NOTES.md) — inactive |

`config` is not a service: it only ships `environment.d/quadlets.conf`
(`QUADLET_STORAGE_PATH`), consumed by the other units through `${...}` expansion.

## Network access

- 🌍 **Public** (Cloudflare Tunnel, outbound only, TLS at the Cloudflare edge):
  `https://n8n.albandiguer.dev`, `https://mealie.albandiguer.dev`. Routes and DNS are
  Terraform-managed — see `cloudflared/NOTES.md`. The tunnel catch-all returns 404.
- 🔒 **VPN-only**: everything else, on `*.lab` and `*.lab.albandiguer.dev`, resolved by
  Pi-hole to `10.0.0.1` and proxied by Caddy.
- Pi-hole, Caddy and cloudflared use **host networking**; all other containers share the
  `podman` bridge network, whose published ports bind `127.0.0.1` only — hence Caddy
  upstreams are always `127.0.0.1:<port>`.
- 🔎 **searxng** is internal-only: its one published port is bound to `127.0.0.1` (so
  Uptime Kuma can probe it), never the LAN. `n8n` reaches it by name at
  `http://searxng:8080` over `searxng.network`, a dedicated DNS-enabled bridge — the
  shared `podman` network has container-name DNS disabled.

## Daily commands

```bash
# Deploy everything from your machine (push to server + stow + daemon-reload)
./bin/deploy-local.sh

# Deploy and restart specific services (also tails their logs)
./bin/deploy-local.sh caddy n8n

# Restart (no arg = every service in services.sh, minus INACTIVE_SERVICES)
./bin/restart.sh
./bin/restart.sh plane caddy

# Secrets, logs, status
ssh minilab '/home/podman/homelab-quadlets/bin/init-secrets.sh'
ssh minilab 'journalctl --user -u n8n.service -n 50'
ssh minilab 'podman ps --format "{{.Names}}\t{{.Status}}"'
```

`restart.sh` derives units from the quadlet files (so pods expand to `plane-pod.service`
plus its members) and skips anything not deployed on the server.

## Storage & secrets conventions

- Everything persistent goes under `$QUADLET_STORAGE_PATH` (default
  `/mnt/minilab-data`, i.e. the Hetzner volume) in a per-service subdirectory; declare it
  as `Volume=${QUADLET_STORAGE_PATH}/<service>/...`. `deploy.sh` creates those
  directories, but ownership sometimes matters (n8n needs UID 100999 — see its NOTES).
- Never use `.env` files for credentials: declare `Secret=<name>,type=env,target=ENV_VAR`
  and create them with `init-secrets.sh`.
- The volume must be mounted **rw** — a read-only mount breaks every container at once
  (see `../infra/TROUBLESHOOTING.md`).

## Adding a service

1. `mkdir -p <service>/.config/containers/systemd <service>/opt/homelab/quadlets/<service>`
2. Write `<service>.container` following the conventions in `AGENTS.md` (health check,
   `Restart=always`, `AutoUpdate=registry`, volumes under `${QUADLET_STORAGE_PATH}`,
   credentials via `Secret=`).
3. Add its config files under `opt/homelab/quadlets/<service>/`.
4. Register it in `bin/services.sh` (`SERVICES`; `INACTIVE_SERVICES` to keep it stopped).
5. Add `reverse_proxy 127.0.0.1:<port>` blocks for both `.lab` names in the Caddyfile.
6. Add `<service>/NOTES.md` — what it is, ports, data path, secrets, gotchas, how to
   verify it.
7. Deploy: `./bin/deploy-local.sh <service>` (pushes, stows, restarts it).

## Manual stow (rarely needed)

```bash
stow --target="$HOME" --restow <service>   # after editing a unit or config
stow --target="$HOME" --delete <service>   # undeploy
systemctl --user daemon-reload             # quadlet regenerates units from the files
```
