# cloudflared (Cloudflare Tunnel)

Outbound-only connector that publishes selected services to the internet without
opening any inbound firewall port.

| | |
|---|---|
| Image | `docker.io/cloudflare/cloudflared:latest` |
| Network | host (no published ports; it dials out to Cloudflare) |
| Secret | `cloudflared_tunnel_token` → `TUNNEL_TOKEN` |
| Tunnel | `minilab` — id `73c61412-268b-47e6-a0e6-96e2dc2d24ac` (Terraform-managed) |

## Where the ingress config lives

The routes are managed **by Terraform**, not the dashboard:

```hcl
# infra/main.tf — cloudflare_zero_trust_tunnel_cloudflared_config.minilab
n8n.albandiguer.dev    → http://localhost:80     # through Caddy
mealie.albandiguer.dev → http://localhost:9000   # straight to the container
(catch-all)            → http_status:404
```

Editing routes in the Cloudflare dashboard will be reverted on the next
`terraform apply`. Add hosts in `main.tf` instead. The DNS CNAMEs
(`n8n`, `mealie` → `<tunnel-id>.cfargotunnel.com`) are also Terraform-managed.

## Token

Get the current token — this is the value `init-secrets.sh` asks for — from Terraform
(the data source reads the live token, so it is always current):

```bash
cd infra && terraform output -json cloudflare_tunnel | jq -r .tunnel_token
```

If the secret is rotated, update it and restart: `./quadlets/bin/restart.sh cloudflared`.

## Verify

```bash
ssh minilab 'systemctl --user status cloudflared.service'
curl -s -o /dev/null -w '%{http_code}\n' https://n8n.albandiguer.dev   # 200/302 from the edge
ssh minilab 'podman logs --tail 20 cloudflared'                        # "Registered tunnel connection"
```
