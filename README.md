# Quadlet Container Services

This directory contains Podman Quadlet definitions for running containerized services on the homelab server.

## What is Quadlet?

Quadlet is a native Podman feature (included in Podman 4.4+) that allows you to define containers as systemd services using simple `.container` files. These are automatically converted to systemd services by the `podman-systemd-generator`.

## Directory Structure

```
quadlets/
├── pihole.container    # Pi-hole DNS server
├── caddy.container     # Caddy reverse proxy
├── Caddyfile          # Caddy configuration
└── README.md          # This file
```

## Deployment

### Automatic Deployment

Use the provided deployment script from the project root:

```bash
./deploy-quadlets.sh
```

This script will:
1. Copy all `.container` files to `/etc/containers/systemd/`
2. Copy the Caddyfile to `/opt/homelab/caddy/`
3. Reload systemd to generate service units
4. Start and enable the services

### Manual Deployment

1. Copy container definitions to the server:
```bash
scp quadlets/*.container root@<server-ip>:/etc/containers/systemd/
scp quadlets/Caddyfile root@<server-ip>:/opt/homelab/caddy/Caddyfile
```

2. SSH to the server and reload systemd:
```bash
ssh root@<server-ip>
systemctl daemon-reload
```

3. Start services:
```bash
systemctl start pihole.service
systemctl start caddy.service
```

## Managing Services

Quadlet containers are managed as regular systemd services:

```bash
# Check status
systemctl status pihole.service

# View logs
journalctl -u pihole.service -f

# Restart service
systemctl restart pihole.service

# Stop service
systemctl stop pihole.service

# Enable auto-start on boot
systemctl enable pihole.service
```

## Container Definitions

### Pi-hole
- **Purpose**: Network-wide ad blocking and local DNS
- **Web UI**: http://pihole.lab/admin (port 8053)
- **DNS Port**: 53 (UDP/TCP)
- **Default Password**: `changeme` (change in production!)

### Caddy
- **Purpose**: Reverse proxy for all services
- **Port**: 80 (HTTP only within VPN)
- **Config**: `/opt/homelab/caddy/Caddyfile`

## Adding New Services

To add a new containerized service:

1. Create a new `.container` file in this directory
2. Follow the Quadlet format (see existing files as examples)
3. Run `./deploy-quadlets.sh` to deploy
4. Add the service to Caddyfile if it needs web access

## Quadlet File Format

Basic structure of a `.container` file:

```ini
[Unit]
Description=Service Description
After=network-online.target

[Container]
Image=docker.io/image:tag
ContainerName=name
Network=host
Environment=KEY=value
Volume=host_path:/container_path

[Service]
Restart=always

[Install]
WantedBy=multi-user.target
```

## Troubleshooting

### Service won't start
```bash
# Check generated systemd unit
systemctl cat pihole.service

# Check for errors
journalctl -u pihole.service --no-pager
```

### Container not found
```bash
# Verify Quadlet files are in correct location
ls -la /etc/containers/systemd/

# Force regeneration
systemctl daemon-reload
```

### DNS issues with Pi-hole
```bash
# Check if Pi-hole is listening
ss -tulpn | grep :53

# Test DNS resolution
dig @localhost google.com
```

## Resources

- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Systemd Service Management](https://www.freedesktop.org/software/systemd/man/systemctl.html)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Caddy Documentation](https://caddyserver.com/docs/)