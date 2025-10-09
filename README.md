# Quadlet Container Services

This directory contains Podman Quadlet definitions for running containerized services on the homelab server.

## What is Quadlet?

Quadlet is a native Podman feature (included in Podman 4.4+) that allows you to define containers as systemd services using simple `.container` files. These are automatically converted to systemd services by the `podman-systemd-generator`.

## Directory Structure

This repository uses GNU Stow for managing quadlet deployments. Each service is a separate stow package:

```
quadlets/
├── pihole/
│   ├── .config/containers/systemd/
│   │   └── pihole.container          # Quadlet definition
│   └── opt/homelab/quadlets/pihole/
│       └── .env                       # Service configuration
├── caddy/
│   ├── .config/containers/systemd/
│   │   └── caddy.container
│   └── opt/homelab/quadlets/caddy/
│       └── Caddyfile                  # Caddy configuration
├── n8n/
├── linkding/
├── mcp-hub/
├── cloudflared/
├── mealie/
├── readeck/
└── bin/
    ├── deploy.sh                      # Deploy services with stow
    └── restart.sh                     # Restart a service
```

## Deployment

### Prerequisites

Install GNU Stow:
```bash
# Fedora/RHEL
sudo dnf install stow

# Ubuntu/Debian
sudo apt install stow

# macOS
brew install stow
```

### Deploy Services

Clone this repository on the server and use the deployment script:

```bash
# Clone to server
git clone <repo-url> ~/quadlets
cd ~/quadlets

# Initialize secrets (first time only)
./bin/init-secrets.sh

# Deploy all services
./bin/deploy.sh

# Deploy specific services
./bin/deploy.sh pihole caddy n8n

# Start services
systemctl --user start pihole.service caddy.service
```

The deploy script uses GNU Stow to create symlinks:
- `.container` files → `~/.config/containers/systemd/`
- Config files → `/opt/homelab/quadlets/<service>/`

### Secrets Management

This setup uses Podman secrets to manage sensitive credentials. Secrets must be initialized before starting services.

**Initialize secrets interactively:**
```bash
./bin/init-secrets.sh
```

This will prompt you for each secret value:
- n8n basic auth credentials
- Linkding superuser credentials
- Mealie default user credentials
- Pi-hole web password
- Cloudflare tunnel token

**List existing secrets:**
```bash
podman secret ls
```

**Update a specific secret:**
```bash
# Remove old secret
podman secret rm n8n_basic_auth_password

# Create new one
echo -n "newsecretvalue" | podman secret create n8n_basic_auth_password -
```

**After updating secrets, restart the affected service:**
```bash
./bin/restart.sh n8n
```

### Manual Deployment with Stow

```bash
# Deploy a single service
cd ~/quadlets
stow --target="$HOME" pihole

# Undeploy a service
stow --target="$HOME" --delete pihole

# Redeploy (useful after updates)
stow --target="$HOME" --restow pihole

# After stowing, reload systemd
systemctl --user daemon-reload
```

## Managing Services

### Using the Restart Script

```bash
# Restart a service and view logs
./bin/restart.sh pihole
```

### Manual Service Management

Quadlet containers run as systemd user services:

```bash
# Check status
systemctl --user status pihole.service

# View logs
journalctl --user -u pihole.service -f

# Restart service
systemctl --user restart pihole.service

# Stop service
systemctl --user stop pihole.service

# Enable auto-start on boot
systemctl --user enable pihole.service

# List all quadlet services
systemctl --user list-units '*.service' | grep -E 'pihole|caddy|n8n|linkding'
```

## Available Services

### Core Services
- **pihole** - Network-wide ad blocking and local DNS (port 53, web UI on :8053)
- **caddy** - Reverse proxy for all services (port 80)

### Applications
- **n8n** - Workflow automation platform
- **linkding** - Bookmark manager
- **mealie** - Recipe manager
- **readeck** - Reading list manager
- **mcp-hub** - MCP Hub

### Infrastructure
- **cloudflared** - Cloudflare tunnel for public access

## Adding New Services

To add a new service:

1. Create the service package structure:
```bash
mkdir -p newservice/.config/containers/systemd
mkdir -p newservice/opt/homelab/quadlets/newservice
```

2. Add the quadlet definition:
```bash
# Create newservice/.config/containers/systemd/newservice.container
[Unit]
Description=New Service
After=network-online.target

[Container]
Image=docker.io/image:tag
ContainerName=newservice
Network=host

[Service]
Restart=always

[Install]
WantedBy=default.target
```

3. Add any config files to `newservice/opt/homelab/quadlets/newservice/`

4. Deploy:
```bash
./bin/deploy.sh newservice
systemctl --user daemon-reload
systemctl --user start newservice.service
```

5. Add to Caddyfile if web access needed

6. Update `bin/deploy.sh` and `bin/restart.sh` to include the new service in the SERVICES array

## Updating Services

To update a service configuration:

```bash
# Edit the quadlet file or config
vim pihole/.config/containers/systemd/pihole.container

# Restow to update symlinks
stow --target="$HOME" --restow pihole

# Reload and restart
systemctl --user daemon-reload
systemctl --user restart pihole.service
```

## Troubleshooting

### Service won't start
```bash
# Check generated systemd unit
systemctl --user cat pihole.service

# Check for errors
journalctl --user -u pihole.service --no-pager -n 50
```

### Stow conflicts
```bash
# If stow reports conflicts, check existing files
ls -la ~/.config/containers/systemd/

# Remove conflicting files manually or use --adopt
stow --target="$HOME" --adopt pihole  # Moves existing files into stow package
```

### Container not found
```bash
# Verify Quadlet files are symlinked
ls -la ~/.config/containers/systemd/

# Force regeneration
systemctl --user daemon-reload
```

### DNS issues with Pi-hole
```bash
# Check if Pi-hole is listening
ss -tulpn | grep :53

# Test DNS resolution
dig @localhost google.com

# View Pi-hole logs
journalctl --user -u pihole.service -f
```

## Volume Setup

On first deployment, create volume directories:

```bash
mkdir -p /mnt/HC_Volume_103621273/{n8n,pihole,caddy,linkding,mcp-hub,cloudflared,mealie}/{data,etc,config,dnsmasq.d}

# n8n runs as UID 1000, maps to host UID 100999 in rootless podman
chown -R 100999:100999 /mnt/HC_Volume_103621273/n8n/data

# Other services owned by podman user
chown -R $(id -u):$(id -g) /mnt/HC_Volume_103621273/{pihole,caddy,linkding,mcp-hub,cloudflared,mealie}
```

## Resources

- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [GNU Stow Documentation](https://www.gnu.org/software/stow/manual/stow.html)
- [Systemd User Services](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Caddy Documentation](https://caddyserver.com/docs/)
