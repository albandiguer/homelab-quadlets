# Headroom (LLM token compression)

Proxy that compresses prompts/completions to cut LLM token usage.

| | |
|---|---|
| Image | `ghcr.io/chopratejas/headroom:latest` |
| Port | `8787` (published on `127.0.0.1`) |
| Data | none (stateless) |
| Access | `http://headroom.lab` |

Stateless, so nothing to back up. Point clients at `http://10.0.0.1:8787` when they
should go through the compressor instead of straight to the model API.

## Verify

```bash
curl -sf http://10.0.0.1:8787/readyz && echo ok
ssh minilab 'podman logs --tail 20 headroom'
```
