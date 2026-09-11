# Mealie (recipes)

| | |
|---|---|
| Image | `ghcr.io/mealie-recipes/mealie:latest` |
| Port | `9000` (published on `127.0.0.1`) |
| Data | `$QUADLET_STORAGE_PATH/mealie/data` → `/app/data` (SQLite) |
| Secrets | `mealie_default_email` / `mealie_default_password` (first run), `openai_api_key` |
| Access | `http://mealie.lab` (VPN) and `https://mealie.albandiguer.dev` (**public**, tunnel → `localhost:9000` directly, bypassing Caddy) |

## Gotchas

**Default credentials only apply once.** `DEFAULT_EMAIL` / `DEFAULT_PASSWORD` seed the
admin user when the database is empty. After that, changing the secret does nothing —
reset the password in the UI (or via the container CLI).

**Public exposure.** Unlike most services, Mealie is reachable from the internet without
a VPN. Keep it on the tunnel ingress list in `infra/main.tf` only if that is intended;
otherwise remove the route and the CNAME.

## Verify

```bash
curl -sI http://mealie.lab | head -1
curl -s -o /dev/null -w '%{http_code}\n' https://mealie.albandiguer.dev
ssh minilab 'podman logs --tail 20 mealie'
```
