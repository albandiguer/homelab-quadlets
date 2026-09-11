# Readeck (read-it-later)

| | |
|---|---|
| Image | `codeberg.org/readeck/readeck:latest` |
| Port | `8000` (published on `127.0.0.1`) |
| Data | `$QUADLET_STORAGE_PATH/readeck` → `/readeck` (SQLite + assets) |
| Secrets | none |
| Access | `http://readeck.lab` |

No secrets: the first user is created through the web UI. All state lives in the volume
directory, so backup/restore is just that folder.

## Verify

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://readeck.lab
ssh minilab 'podman logs --tail 20 readeck'
```
