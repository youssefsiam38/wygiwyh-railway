# Marketplace audit — WYGIWYH

| Item | Result |
|------|--------|
| Upstream | https://github.com/eitchtee/WYGIWYH, active (0.23.2 2026-09-13; commits 2026-10) |
| Licence | AGPL-3.0 (verified in `LICENSE`); no commercial or NC clause; run unmodified with source linked |
| Brand | Generic icon; "not affiliated" notice in README, OVERVIEW, notices |
| Prebuilt image | Yes, `eitchtee/wygiwyh` on Docker Hub, amd64 + arm64, versioned tags |
| External services | None required. OIDC optional, user-supplied |
| Marketplace gap | `gapscan.py wygiwyh` → GAP (no template) |

## Security review

| Risk in a stock deploy | Mitigation |
|------------------------|------------|
| Open registration | None upstream: allauth `SOCIALACCOUNT_ONLY=True`, `/auth/signup/` 404; users added by an admin |
| First-run admin page | None: admin created from `ADMIN_EMAIL` + generated `ADMIN_PASSWORD` before gunicorn listens |
| Default `SECRET_KEY` empty | Generated per deploy |
| CSRF / host checks behind a proxy | `URL` and `DJANGO_ALLOWED_HOSTS` from `RAILWAY_PUBLIC_DOMAIN`; `HTTPS_ENABLED=true` |
| Health check rejected by `ALLOWED_HOSTS` | `healthcheck.railway.app` allowed |
| Non-root image vs root-owned volume | `RAILWAY_RUN_UID=0` + `chown` start command; app processes still run as `app` |
| Postgres `lost+found` | Volume at parent; `PGDATA` subdir |
| OIDC auto sign-up | Off (no OIDC by default); documented `OIDC_ALLOW_SIGNUP=false` |

## Test inventory

| Script | Assertions |
|--------|-----------|
| `tests/static.sh` | 27 |
| `tests/smoke.sh` | 45 |
| `tests/persistence.sh` | 25 |
| `tests/railway-smoke.sh` | live, HTTPS (full + `--verify` after redeploy) |

## Deploy-time inputs

- `ADMIN_EMAIL` (required). `ADMIN_PASSWORD`, `SECRET_KEY` and the DB password are generated.

## Verdict

SHIPPABLE, no wrapper (stock image, start command override for volume ownership).
