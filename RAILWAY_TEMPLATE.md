# Railway template configuration

The template's exact configuration. Reproduce it from this file if it ever has to be rebuilt.

| | |
|---|---|
| Name | WYGIWYH |
| Code | `wygiwyh` |
| Template id | `fa7d8459-46a7-4565-a2cf-aecc48166e7f` |
| Deploy URL | https://railway.com/deploy/wygiwyh |
| Category | Other |
| Card description | Self-hosted multi-currency personal finance tracker with PostgreSQL |
| Icon | `assets/icon.png` |
| Overview markdown | `marketplace/OVERVIEW.md` (Railway enforces its section headings) |

Generated values use Railway's `secret()` function: `hexN` is `${{secret(N, "abcdef0123456789")}}` and `alnumN` is
`${{secret(N, "a-zA-Z0-9")}}` spelled out. Alphanumeric passwords are used wherever a value is embedded in a
connection URL, so nothing needs percent-encoding. Images are referenced by tag and digest (see `UPSTREAM.md`).

## Services

### `db`

| Field | Value |
|---|---|
| Source | `postgres:15.19-bookworm@sha256:d4a8e1f88f475ee3e0137fa89d21ebc59f6c6ab16bf369ee92907607cc3455ae` |
| Public domain | none |
| Volume | `/var/lib/postgresql` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `POSTGRES_USER` | `wygiwyh` |
| `POSTGRES_DB` | `wygiwyh` |
| `POSTGRES_PASSWORD` | generated, alnum40 |
| `PGDATA` | `/var/lib/postgresql/pgdata` |

### `web`

| Field | Value |
|---|---|
| Source | `eitchtee/wygiwyh:0.23.2@sha256:64b02913916b60df21dcb70a7d44d98c20d8d5e46690e0ea5cad2d3e828bbd2b` |
| Public domain | target port 8000 |
| Volume | `/usr/src/app/attachments` |
| Start command | `sh -c 'chown -R app:app /usr/src/app/attachments && exec /start-single'` |
| Healthcheck | `/login/`, timeout from `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `ADMIN_EMAIL` | required input, no default |
| `ADMIN_PASSWORD` | generated, alnum24 |
| `SECRET_KEY` | generated, alnum64 |
| `URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |
| `DJANGO_ALLOWED_HOSTS` | `${{RAILWAY_PUBLIC_DOMAIN}} healthcheck.railway.app localhost 127.0.0.1` |
| `HTTPS_ENABLED` | `true` |
| `DEBUG` | `false` |
| `SQL_HOST` | `${{db.RAILWAY_PRIVATE_DOMAIN}}` |
| `SQL_PORT` | `5432` |
| `SQL_DATABASE` | `${{db.POSTGRES_DB}}` |
| `SQL_USER` | `${{db.POSTGRES_USER}}` |
| `SQL_PASSWORD` | `${{db.POSTGRES_PASSWORD}}` |
| `PORT` | `8000` |
| `INTERNAL_PORT` | `8000` |
| `WEB_CONCURRENCY` | `2` |
| `TASK_WORKERS` | `1` |
| `TZ` | `UTC` |
| `RAILWAY_RUN_UID` | `0` |
| `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` | `300` |
| `OIDC_CLIENT_NAME` | optional, unset |
| `OIDC_CLIENT_ID` | optional, unset |
| `OIDC_CLIENT_SECRET` | optional, unset |
| `OIDC_SERVER_URL` | optional, unset |
| `OIDC_ALLOW_SIGNUP` | optional, unset |
| `ENABLE_SOFT_DELETE` | optional, unset |
| `KEEP_DELETED_ENTRIES_FOR` | optional, unset |

## Notes

- No wrapper image: the stock `eitchtee/wygiwyh` runs unmodified. The start command
  `sh -c 'chown -R app:app /usr/src/app/attachments && exec /start-single'` with `RAILWAY_RUN_UID=0` hands the
  root-owned Railway volume to the image's `app` user; supervisord then runs gunicorn and the procrastinate worker as `app`.
- `DJANGO_ALLOWED_HOSTS` includes `healthcheck.railway.app` (Railway's health-check Host header); `URL` is the CSRF
  trusted origin; `HTTPS_ENABLED=true` makes the session cookie Secure and trusts `X-Forwarded-Proto`.
- Health check `/login/` (with the trailing slash).
- PostgreSQL 15: volume at `/var/lib/postgresql`, `PGDATA=/var/lib/postgresql/pgdata`.
- No public sign-up exists upstream (allauth `SOCIALACCOUNT_ONLY=True`); the admin is created from `ADMIN_EMAIL` and
  the generated `ADMIN_PASSWORD` once, before gunicorn listens.
- Live e2e over HTTPS on a clean-room deploy of this template: 28/28 full run; 23/23 `--verify` after redeploying
  `db` and `web` (database rows and the attachment file survived; admin not re-created).
