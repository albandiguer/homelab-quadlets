# AGENTS Guide — homelab-quadlets

Rootless Podman Quadlets powering the minilab homelab. Conventions for agents working
in this repo; the "why" behind each failure mode lives in the per-service `NOTES.md`
files and in `../infra/TROUBLESHOOTING.md`.

## Layout & sources of truth

- Each service is a stow package: `<service>/.config/containers/systemd/<service>.container`
  plus config files under `<service>/opt/homelab/quadlets/<service>/`.
- **`bin/services.sh` is the only service list.** `deploy.sh`, `deploy-local.sh` and
  `restart.sh` all read it — never hardcode a service list anywhere else.
- `config/.config/environment.d/quadlets.conf` defines `QUADLET_STORAGE_PATH`
  (default `/mnt/minilab-data`); every persistent volume hangs off it.
- Secrets are Podman secrets created by `bin/init-secrets.sh`; never commit credentials
  or add `.env` files.

## Commands

- Deploy from the laptop: `./bin/deploy-local.sh [service...]` (push + stow +
  daemon-reload; named services are also restarted and tailed).
- Deploy on the server: `ssh minilab '/home/podman/homelab-quadlets/bin/deploy.sh'`.
- Restart: `./bin/restart.sh [service...]` — no argument restarts everything in
  `services.sh` minus `INACTIVE_SERVICES`.
- `ssh minilab` lands as the `podman` user over WireGuard (`10.0.0.1`); port 22 is
  firewalled off, and `sudo -u podman` is only needed when starting from root.

## Quadlet conventions

- Section order `[Unit]`, `[Container]`, `[Service]`, `[Install]`; keep units minimal.
- `AutoUpdate=registry` for active services.
- `HealthCmd` + `HealthInterval=30s` / `HealthTimeout=10s` / `HealthRetries=3`.
- `Restart=always` and `RestartSec=30` in `[Service]`.
- Fully-qualified image references.
- Data volumes under `${QUADLET_STORAGE_PATH}/<service>/...`; read-only config mounts
  from the stowed path.
- Rootless port limit is 53 (`net.ipv4.ip_unprivileged_port_start=53`); bridge-network
  ports publish on `127.0.0.1`, so Caddy upstreams must be `127.0.0.1:<port>`.
- One container name, directory name and unit name per service, kebab-case.

## Adding a service

1. Create `<service>/.config/containers/systemd/<service>.container` and
   `<service>/opt/homelab/quadlets/<service>/`.
2. Register the service in `bin/services.sh`.
3. Add `reverse_proxy 127.0.0.1:<port>` blocks for `http://<name>.lab` and
   `http://<name>.lab.albandiguer.dev` in the Caddyfile.
4. Write `<service>/NOTES.md`: purpose, image/port, data path, secrets, gotchas, and the
   commands that prove it works.
5. `./bin/deploy-local.sh <service>`.

## Scripts

Bash, `set -e` where it is safe, helpful `echo` output, guarded prompts for anything
destructive. Fail early with an instructive message rather than continuing.

## Verifying changes

No automated test suite — validate with the service's own `NOTES.md` commands:
`systemctl --user status <service>.service`, `systemctl --user cat <service>.service`,
and `journalctl --user -u <service>.service -n 50`. For script changes, prefer a dry
run with stubbed `ssh`/`systemctl` over guessing.
