# Pi-hole (DNS)

Ad-blocking DNS resolver that also answers the internal wildcards. **Host network**,
so it binds the host's port 53 directly.

| | |
|---|---|
| Image | `docker.io/pihole/pihole:latest` |
| Ports | `53/udp` + `53/tcp` (DNS), `8053/tcp` (admin UI), `123/udp` (NTP) |
| Data | `$QUADLET_STORAGE_PATH/pihole/etc` → `/etc/pihole`, `.../pihole/dnsmasq.d` → `/etc/dnsmasq.d` |
| Secret | `pihole_webpassword` → `FTLCONF_webserver_api_password` |
| Access | `http://pihole.lab` (Caddy redirects `/` → `/admin`, proxies to `127.0.0.1:8053`) |

Internal names it answers (via `FTLCONF_misc_dnsmasq_lines`):

```
address=/.lab/10.0.0.1
address=/.lab.albandiguer.dev/10.0.0.1
address=/.home.arpa/10.0.0.1
```

`FTLCONF_dns_listeningMode=all` makes FTL listen on every interface. That is safe here
because the host firewall exposes only WireGuard, but it does mean Pi-hole is
reachable by any VPN peer — not just localhost.

## Gotchas

**1. Port 53 already in use → no DNS at all.** `systemd-resolved` (enabled by the
Fedora image) binds `127.0.0.53:53` + `127.0.0.54:53`. FTL then logs
`CRIT: failed to create listening socket for port 53: Address in use` and serves *no*
DNS. `stop`+`disable` is not enough — resolved is re-activated by its sockets. Mask it:

```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
sudo systemctl mask systemd-resolved     # durable
./quadlets/bin/restart.sh pihole         # FTL only binds :53 at startup
```

(Fixed in `infra/cloud-init.yaml.tpl` for future rebuilds.)

**2. Rootless privilege for port 53.** Requires `net.ipv4.ip_unprivileged_port_start=53`
(set by cloud-init). Without it the container cannot bind 53.

**3. Read-only data dir.** If the data volume is mounted `ro` (or the ro flag got
locked, see `infra/TROUBLESHOOTING.md`), FTL logs
`Cannot initialize in-memory database` / `Read-only file system` and again serves no
DNS. Symptom in every service, not just this one: nothing can write to the volume.

**4. Web password.** Comes from the `pihole_webpassword` secret; updating the secret
and restarting the container applies the new password (no `pihole -a -p` needed).

## Verify

```bash
dig +short @10.0.0.1 linkding.lab            # -> 10.0.0.1 (from any VPN client)
dig +short @10.0.0.1 anything.lab            # -> 10.0.0.1 (wildcard)
sudo ss -lunp | grep 0.0.0.0:53              # UDP + TCP listeners owned by pihole-FTL
ssh minilab 'podman logs --tail 30 pihole'   # look for "listening on 0.0.0.0 port 53"
```

Client-side: `*.lab` only resolves while the WireGuard tunnel is up **and** the tunnel
config carries `DNS = 10.0.0.1, 1.1.1.1`. Check with `scutil --dns | grep nameserver`
(macOS). "Server Not Found" in the browser while `dig @10.0.0.1` works means the client
resolver, not Pi-hole.
