# Linkding (bookmarks)

| | |
|---|---|
| Image | `docker.io/sissbruecker/linkding:latest` |
| Port | `9090` (published on `127.0.0.1`) |
| Data | `$QUADLET_STORAGE_PATH/linkding/data` → `/etc/linkding/data` (SQLite) |
| Secrets | `linkding_superuser_name` / `linkding_superuser_password` |
| Access | `http://linkding.lab` |

## Gotchas

**The superuser secrets only seed an empty database.** `LD_SUPERUSER_NAME` /
`LD_SUPERUSER_PASSWORD` are applied on first run; changing the secret later does **not**
change the existing account's password. To reset it, use the container:

```bash
ssh minilab 'podman exec -it linkding python manage.py changepassword <user>'
# or create another admin:
ssh minilab 'podman exec -it linkding python manage.py createsuperuser'
```

**Unhealthy ≠ broken.** The container reports `unhealthy` when the health endpoint
(`/health`) is not answerable from inside, but the UI can still be fine — confirm with
`curl -sI http://linkding.lab` and the logs before chasing it.

## Verify

```bash
curl -sI http://linkding.lab | head -1
ssh minilab 'podman logs --tail 20 linkding'
```
