# Discourse

Self-hosted forum, running as a **single all-in-one container**: Rails/Unicorn +
nginx + PostgreSQL + Redis all inside `discourse.service`, with everything persistent
on the Hetzner volume.

## Why a locally built image

There is no production-ready prebuilt image to pull:

| Image | Why not |
|---|---|
| `discourse/discourse` | Official but **experimental** and **web-only** (needs external PostgreSQL + Redis); upstream says not for production |
| `discourse/base` | Base image only — needs the `discourse_docker` launcher (Docker/buildx) to become runnable |
| `bitnami/discourse` | Deprecated upstream, and also expects external PostgreSQL + Redis |

So the all-in-one image has to be built. The official `discourse_docker` launcher
produces exactly that, but needs Docker/buildx; instead we rebuild the same image here
from the official templates with `pups` (the tool the launcher itself uses), driven by
Quadlet:

| Unit | What |
|---|---|
| `discourse-build.service` | `podman build` of `opt/homelab/quadlets/discourse/Containerfile` (`discourse.build`) |
| `discourse.service` | the container, `Image=discourse.build` |

The Containerfile applies `samples/standalone.yml` (postgres + redis + web + ratelimited
templates) on top of the official release base image
`discourse/base:2.0.20260928-0031-stable`, exactly like `./launcher bootstrap app`.

## Hostname / access

Discourse has **one canonical hostname** (`DISCOURSE_HOSTNAME`): it builds every link,
asset URL and email with it, regardless of the Host header used to reach it. Until the
public domain is decided it is `discourse.lab` — both VPN names below proxy to the same
container and land on it:

- **VPN**: `http://discourse.lab` and `http://discourse.lab.albandiguer.dev`.

nginx listens on `80` in the container, published as `8081` (host port 8080 belongs to
searxng, which binds `127.0.0.1:8080`); Caddy routes both
names to it. Caddy/Cloudflare terminate TLS, so the container serves plain HTTP
(`DISCOURSE_FORCE_HTTPS=false`).

### Changing the canonical host later

Moving to the public domain is **not a rebuild** — `DISCOURSE_HOSTNAME` is just an env
var. Set it to the public host, restart, then rewrite the already-baked links:

```bash
podman exec -it discourse rake posts:rebake
```

Uploads live under `/shared/uploads` and are referenced by path, so they survive the
move. Only post HTML baked with the old host (and any emails) keeps the old name until
rebaked. Do the switch together with the DNS/tunnel steps below.

### Public exposure (TODO, not done here)

No public domain yet. When there is one, expose it exactly like n8n/mealie — through the
Terraform-managed Cloudflare Tunnel, **not** with a Pi-hole *split-horizon* record
(a local DNS override that answers the public name with `10.0.0.1` for VPN clients
only, so the same name resolves differently inside and outside the VPN):

1. Set `DISCOURSE_HOSTNAME` to the public host and redeploy (Discourse bakes it into
   links and emails).
2. Add the host to the `cloudflare_zero_trust_tunnel_cloudflared_config` ingress in
   `infra/main.tf` (before the `http_status:404` catch-all):
   ```hcl
   { hostname = "forum.example.org", service = "http://localhost:80" }
   ```
3. Add a proxied CNAME (`name = "forum"`) to `<tunnel-id>.cfargotunnel.com` in the
   same zone.
4. Enable Cloudflare **Always Use HTTPS** and **Automatic HTTPS Rewrites**.

Public requests then reach Caddy on port 80 like n8n does, and the tunnel catch-all
still 404s everything else.

## Data (all on the external volume)

`$QUADLET_STORAGE_PATH` defaults to `/mnt/minilab-data`:

- `${QUADLET_STORAGE_PATH}/discourse/shared` → `/shared`
  - `postgres_data/` PostgreSQL cluster  - `redis_data/` Redis AOF
  - `uploads/`, `backups/`, `log/`, `state/`, `tmp/`
- `${QUADLET_STORAGE_PATH}/discourse/log` → `/var/log` (nginx / postgres / redis logs)

`deploy.sh` creates these directories from the `Volume=` lines. Inside the container the app
does not write to them directly: the image symlinks `public/uploads`, `public/backups`,
`tmp/{backups,restores}` and `log/*.log` onto `/shared/...` (upstream does this in its
`build` block, which this Containerfile skips, so it is done explicitly). Rails logs are
therefore at `${QUADLET_STORAGE_PATH}/discourse/shared/log/rails/production.log`.

## Secrets

- `discourse_db_password` (created by `bin/init-secrets.sh`) → `DISCOURSE_DB_PASSWORD`,
  used both to create the local `discourse` PostgreSQL role and by the app to connect.
  The container's `/usr/local/bin/create_db` re-applies it to the role on **every** boot
  (`CREATE_DB_ON_BOOT=1`), so a rotated or regenerated secret is reconciled automatically —
  no manual `ALTER USER`, unlike Plane.

Non-secret config lives in `.config/environment.d/discourse.conf`
(`DISCOURSE_HOSTNAME`, `DISCOURSE_DEVELOPER_EMAILS`); systemd expands it into the unit.

## Setup

```bash
# 1. Create the DB password secret
ssh minilab '/home/podman/homelab-quadlets/bin/init-secrets.sh'

# 2. Deploy (pushes, stows, daemon-reload)
./bin/deploy-local.sh discourse

# 3. Start: the first start builds the image (a few minutes), then boots Discourse
ssh minilab 'systemctl --user start discourse.service'
```

Set `DISCOURSE_HOSTNAME` / `DISCOURSE_DEVELOPER_EMAILS` in the repo copy of
`.config/environment.d/discourse.conf` before deploying (the deployed copy is a stow
symlink, so editing it on the server edits the repo checkout); log out/in afterwards so
the systemd user session picks the values up.

The very first boot initialises the PostgreSQL cluster on the volume, runs `db:migrate`
and `assets:precompile`, then starts Unicorn. nginx returns 502 until Unicorn is ready;
the health check reports healthy afterwards.

### First admin without SMTP

No SMTP is configured, so account emails are not sent. Create the admin from the CLI:

```bash
ssh minilab 'podman exec -it discourse rake admin:create'
```

### Adding SMTP (recommended before opening signups)

Discourse only sends transactional mail (signup, password reset, notifications), so a
free tier is plenty. Good options, all offering authenticated SMTP relay:

| Provider | Free tier | Notes |
|---|---|---|
| Brevo (ex-Sendinblue) | 300 emails/day | best-known free tier, plain SMTP |
| Mailjet | 200/day, 6 000/month | SMTP + API |
| Resend | 100/day, 3 000/month | developer-focused, SMTP available |
| SendGrid | 100/day | long-standing, SMTP + API |

Whichever you pick, verify the sending domain (SPF + DKIM DNS records in the Cloudflare
zone) and use its SMTP host on port 587 below.

Add to `.config/environment.d/discourse.conf` and reference them from
`discourse.container`:

```ini
DISCOURSE_SMTP_ADDRESS=smtp.example.com
DISCOURSE_SMTP_PORT=587
DISCOURSE_SMTP_USER_NAME=forum@example.com
```

```
Environment=DISCOURSE_SMTP_ADDRESS=${DISCOURSE_SMTP_ADDRESS}
Environment=DISCOURSE_SMTP_PORT=${DISCOURSE_SMTP_PORT}
Environment=DISCOURSE_SMTP_USER_NAME=${DISCOURSE_SMTP_USER_NAME}
Secret=discourse_smtp_password,target=DISCOURSE_SMTP_PASSWORD,type=env
```

(add `discourse_smtp_password` to `bin/init-secrets.sh` if you do).

## Updating Discourse

The base image and the templates are **pinned** in the Containerfile so the build is
reproducible. To move to a newer release, bump both together and rebuild:

```ini
ARG BASE_IMAGE=docker.io/discourse/base:2.0.<new-timestamp>-stable
ARG TEMPLATES_REF=<new-discourse_docker-commit>
```

```bash
./bin/deploy-local.sh discourse       # or: git pull + stow on the server
ssh minilab 'systemctl --user restart discourse-build.service discourse.service'
```

Then run the migration step (already part of boot, but if you want it explicit):
`podman exec -it discourse rake db:migrate` — normally unnecessary.

## Gotchas

**The image is built on the server.** `discourse-build.service` needs network access
(pulls `discourse/base` ~1.5 GB once and the templates) and several minutes the first
time; a no-op rebuild with layer cache takes seconds. It is *not* covered by
`AutoUpdate=registry` — updates go through the Containerfile bump above.

**Uploads live on the volume only through symlinks — a missing one silently loses files.**
`public/uploads` must be a symlink to `/shared/uploads`; if it is (or becomes) a real
directory, Discourse happily writes avatars, attachments and theme screenshots into the
container's writable layer, which Quadlet discards on every restart. The DB rows survive,
so you get broken images and empty theme previews instead of an error. Check with:

```bash
ssh minilab 'podman exec discourse readlink /var/www/discourse/public/uploads'  # /shared/uploads
```

Same for `public/backups`, `tmp/{backups,restores}` and `log/*.log`. The screenshots of
the bundled Foundation/Horizon themes (`themes/*/screenshots/*.png`, content-addressed
under `/uploads/default/original/1X/<sha1>.png`) are restored by copying the repo file to
its sha1 path on the volume — re-importing the theme does not recreate a missing file.

**The Ember frontend bundle is built into the image, never on boot.** The web template's
boot hook precompiles with `SKIP_EMBER_CLI_COMPILE=1`, so a container start only
regenerates the Rails/propshaft assets — `frontend/discourse/dist` (vendor.js, chunk-*.js)
and the plugin bundles in `app/assets/generated` must already exist. The Containerfile's
`rake assets:precompile:build` step provides them, downloading Discourse's prebuilt bundle
for the pinned version+commit (falling back to `pnpm build` when the JS tree is dirty).
Omit it and **every page render fails** with
`ActionView::Template::Error: The asset 'vendor.js' was not found in the load path`
(HTTP 500), while `/srv/status` still answers 200 — so the health check, `podman ps` and
Uptime Kuma all stay green on a completely broken site. Always check a real page:

```bash
ssh minilab 'curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8081/'
```

**Assets recompile on every container start.** Quadlet runs the container with `--rm`,
so a restart creates a fresh writable layer and `/var/www/discourse/public/assets` is
rebuilt (`PRECOMPILE_ON_BOOT=1`). On the ARM CAX11 this is roughly a minute. Keep
`PRECOMPILE_ON_BOOT=1`: setting it to `0` breaks the first boot after an image update.

**Don't rename the PostgreSQL major version casually.** The Containerfile's templates
are written for PostgreSQL 18 (what the pinned base ships). If you change `BASE_IMAGE`
to one built with a different `PG_MAJOR`, the templates' paths (`/etc/postgresql/18`,
`/usr/lib/postgresql/18`) no longer match — bump `TEMPLATES_REF` to a matching
discourse_docker commit at the same time.

**Memory.** Discourse wants ~2–4 GB. The CAX11 is small; `UNICORN_WORKERS=1` and
`UNICORN_SIDEKIQS=1` keep it in check, but watch `free -h` if other services grow.

## Verify

```bash
./bin/restart.sh discourse
ssh minilab 'systemctl --user status discourse.service discourse-build.service'
ssh minilab 'podman ps --format "{{.Names}}\t{{.Status}}"'
ssh minilab 'curl -fsS http://127.0.0.1:8081/srv/status'   # expect 200 (health only)
ssh minilab 'curl -fsS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8081/'  # expect 200 (page render)
dig +short @10.0.0.1 discourse.lab                         # -> 10.0.0.1 (VPN)
curl -sI http://discourse.lab | head -1                    # expect HTTP/1.1 200
ssh minilab 'podman exec discourse ls /shared'             # postgres_data, uploads, ...
ssh minilab 'podman exec discourse readlink /var/www/discourse/public/uploads'  # /shared/uploads
ssh minilab 'podman exec discourse ls /shared/uploads/default/original/1X'      # theme screenshots
```

## Logo

`opt/homelab/quadlets/discourse/logo.svg` is a starting mark (the *Deux Jumeaux* islets
off the Hendaye beach, with a no-tractopelle sign; no wording). Upload it in
**Admin → Appearance → Logos** (`Site logo`) — site assets are stored in the
database/uploads on the volume, not read from this file.
