# homelab-quadlets

Rootless Podman containers managed via [Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) + [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html) on Fedora.

## Services

| Service | Description |
|---------|-------------|
| 🛡️ pihole | DNS ad-blocking |
| 🔀 caddy | Reverse proxy |
| ⚡ n8n | Workflow automation |
| 🔖 linkding | Bookmarks |
| 🍽️ mealie | Recipes |
| 📖 readeck | Read-it-later |
| 🌐 cloudflared | Cloudflare tunnel |
| 🗜️ headroom | LLM token-compression proxy |

## Usage

```bash
# First time: initialize secrets
./bin/init-secrets.sh

# Deploy all services
./bin/deploy.sh

# Deploy from local machine (push + stow + reload)
./bin/deploy-local.sh

# Deploy and restart specific services
./bin/deploy-local.sh caddy n8n

# Restart a service
./bin/restart.sh <service>
```
