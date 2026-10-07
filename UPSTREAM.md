# Upstream

- Project: https://github.com/eitchtee/WYGIWYH (AGPL-3.0)
- Official image: `eitchtee/wygiwyh` on Docker Hub (linux/amd64 + linux/arm64)
- Reference deployment: upstream `docker-compose.prod.yml` (`eitchtee/wygiwyh:latest` + `postgres:15-bookworm`)

## Pinned versions

| Component | Reference |
|-----------|-----------|
| WYGIWYH | `eitchtee/wygiwyh:0.23.2@sha256:64b02913916b60df21dcb70a7d44d98c20d8d5e46690e0ea5cad2d3e828bbd2b` |
| PostgreSQL | `postgres:15.19-bookworm@sha256:d4a8e1f88f475ee3e0137fa89d21ebc59f6c6ab16bf369ee92907607cc3455ae` |

Both are multi-arch manifest-list digests. The template stays on PostgreSQL 15 like upstream's compose file.

## Refreshing a digest

```bash
curl -s https://hub.docker.com/v2/repositories/eitchtee/wygiwyh/tags/X.Y.Z/ | jq -r .digest
curl -s https://hub.docker.com/v2/repositories/library/postgres/tags/15.N-bookworm/ | jq -r .digest
```
