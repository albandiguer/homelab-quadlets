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
asset URL and email with it, regardless of the Host header used to reach it.

- **Public**: `https://forum.molereskoak.org` — Cloudflare Tunnel → Caddy → here.
- **VPN**: `http://discourse.lab` and `http://discourse.lab.albandiguer.dev` still route
  to the same container, but everything they render links to the public host.

nginx listens on `80` in the container, published as `8081` (host port 8080 belongs to
searxng, which binds `127.0.0.1:8080`); Caddy routes all three names to it.
Caddy/Cloudflare terminate TLS, so the container serves plain HTTP and
`DISCOURSE_FORCE_HTTPS=true` makes it emit `https://` links.

### Public exposure

Exposed exactly like n8n/mealie — through the Terraform-managed Cloudflare Tunnel,
**not** with a Pi-hole *split-horizon* record (a local DNS override that answers the
public name with `10.0.0.1` for VPN clients only, so the same name resolves differently
inside and outside the VPN):

1. `DISCOURSE_HOSTNAME=forum.molereskoak.org` in `.config/environment.d/discourse.conf`.
2. `infra/main.tf`: ingress route `{ hostname = "forum.molereskoak.org", service = "http://localhost:80" }`
   before the `http_status:404` catch-all, plus the proxied CNAME
   `cloudflare_dns_record.forum_public` → `<tunnel-id>.cfargotunnel.com` in the
   `molereskoak.org` zone (`var.cloudflare_zone_id_molereskoak`).
3. The Caddyfile vhost `http://forum.molereskoak.org` → `127.0.0.1:8081`.

Public requests reach Caddy on port 80, and the tunnel catch-all still 404s everything
else. Step 2 needs `terraform apply` (user-run); 1 and 3 ship with a normal deploy:
`./bin/deploy-local.sh caddy discourse`.

### Changing the canonical host again

Not a rebuild — `DISCOURSE_HOSTNAME` is just an env var. Set it, restart, then rewrite
the already-baked links:

```bash
podman exec -it discourse rake posts:rebake
```

Uploads live under `/shared/uploads` and are referenced by path, so they survive the
move. Only post HTML baked with the old host (and any emails) keeps the old name until
rebaked.

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

### Outbound mail (Brevo SMTP)

Wired, using Brevo's free tier (300/day) — enough, since Discourse only sends
transactional mail (signup, password reset, notifications). The non-secret half lives in
`.config/environment.d/discourse.conf` (`DISCOURSE_SMTP_ADDRESS=smtp-relay.brevo.com`,
port `587`, user `bd983a001@smtp-brevo.com`, `DISCOURSE_NOTIFICATION_EMAIL`); the SMTP key
is the `discourse_smtp_password` Podman secret, injected as `DISCOURSE_SMTP_PASSWORD` by
`discourse.container`. `smtp_*` are ordinary Discourse site settings, so the
`DISCOURSE_`-prefixed env vars are the override mechanism (same as `FORCE_HTTPS`).

To (re)set the key:

```bash
read -rs BREVO_KEY
printf '%s' "$BREVO_KEY" | ssh minilab 'podman secret create discourse_smtp_password -'
unset BREVO_KEY                      # then redeploy: ./bin/deploy-local.sh discourse
```

Brevo refuses senders it has not verified, and `notification_email` is
`noreply@molereskoak.org`, so **verify the molereskoak.org domain in Brevo** (Senders →
Domains) and add the SPF/DKIM records it prints to the Cloudflare zone — until then every
message is rejected ("sender not valid"). Adding a single verified gmail sender instead
works for a first test, but then `DISCOURSE_NOTIFICATION_EMAIL` has to point at it.

## Updating Discourse

The app source **ships inside the base image**, so the update is one thing: bump
`BASE_IMAGE` and rebuild. Anything written about "bump `TEMPLATES_REF` too" is only about
the runtime (`PG_MAJOR` in the image must match the paths in the templates, currently 18).

The admin banner names release tags (`2026.8.x`, `2026.9.0`, …) that have **no base image**:
upstream's launcher reaches those with a `git fetch/checkout` plus `bundle install` +
`pnpm install` at build time, which this Containerfile deliberately skips (the `build` tag).
Only two flavours are published:

| Tag | App source |
|---|---|
| `2.0.<date>-<time>-stable` | ESR / `release/2026.7` — conservative, gets patches only |
| `2.0.<date>-<time>` | `main` / tests-passed — newest code (what this repo runs) |

So the whole update procedure is:

```bash
# 1. Safety net: migrations are one-way, the dump is the only rollback.
ssh minilab 'podman exec discourse su postgres -c "pg_dump -Fc -d discourse" > /tmp/pre.dump'
ssh minilab 'podman cp /tmp/pre.dump discourse:/shared/backups/ && rm /tmp/pre.dump'

# 2. Bump the tag in Containerfile, deploy, and build (the running forum keeps serving).
./bin/deploy-local.sh
ssh minilab 'systemctl --user start discourse-build.service'

# 3. Switch over: the new container migrates and precompiles on boot (~2-5 min).
ssh minilab 'systemctl --user restart discourse.service'
```

Verify with `podman exec -it discourse rails runner 'puts Discourse::VERSION::STRING'`, a
page render (not just `/srv/status`) and the theme previews. The old image stays on disk;
`podman image prune` reclaims it once the upgrade looks good — rolling *back* means
restoring the dump, not the image.

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
