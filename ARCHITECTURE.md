# Architecture

```
            Internet (HTTPS, Railway edge)
                       │  X-Forwarded-Proto: https
                       ▼
   ┌───────────────────────────────────────────┐
   │ web  (eitchtee/wygiwyh, $PORT=8000)        │  supervisord:
   │   gunicorn 0.0.0.0:8000 (Django + whitenoise)│   - gunicorn (migrate, setup_users, serve)
   │   procrastinate worker (background jobs)   │   - procrastinate worker (TASK_WORKERS)
   │   volume /usr/src/app/attachments          │
   └───────────────────┬───────────────────────┘
                       │ db.railway.internal:5432 (private, IPv6)
                       ▼
   ┌───────────────────────────────────────────┐
   │ db  (PostgreSQL 15)                        │  volume /var/lib/postgresql, PGDATA …/pgdata
   └───────────────────────────────────────────┘
```

## One web service, no wrapper

The official image's default command (`/start-single`) runs supervisord with two programs as the `app` user: the
web process (`migrate`, `setup_users` which creates the admin from `ADMIN_EMAIL`/`ADMIN_PASSWORD` if it does not
exist, `setup_oauth`, then gunicorn on `0.0.0.0:$INTERNAL_PORT`) and the procrastinate worker, which waits for the
migrations and then runs scheduled jobs (recurring transactions, exchange-rate fetches, cleanup). The template runs
this unchanged.

Gunicorn binds IPv4 only, which is fine: the web service is reached through Railway's public edge, never over the
private network. `PORT=INTERNAL_PORT=8000` so the domain and the health check (`/login/`) hit gunicorn.

## Why the start command is overridden

The image ends with `USER app`, but Railway mounts volumes owned by root, so the `app` user could not write
attachments. The template sets `RAILWAY_RUN_UID=0` and the start command
`sh -c 'chown -R app:app /usr/src/app/attachments && exec /start-single'`. supervisord (root) still starts gunicorn
and the worker as `app` (`user=app` in upstream's `supervisord.conf`), so the app itself never runs as root.

## Django behind Railway's proxy

| Variable | Value | Why |
|----------|-------|-----|
| `URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Becomes `CSRF_TRUSTED_ORIGINS`; form posts over HTTPS need it |
| `DJANGO_ALLOWED_HOSTS` | `${{RAILWAY_PUBLIC_DOMAIN}} healthcheck.railway.app localhost 127.0.0.1` | Railway's health check sends `Host: healthcheck.railway.app`; without it the check gets 400 |
| `HTTPS_ENABLED` | `true` | Secure session cookie, `SECURE_PROXY_SSL_HEADER` trusts `X-Forwarded-Proto` |
| `SECRET_KEY` | generated | Django signing key |

## Auth

Django sessions; local login by email at `/login/` (CSRF-protected form). The REST API (`/api/`) accepts the
session (with the CSRF header), HTTP Basic, and personal API tokens. allauth runs with `SOCIALACCOUNT_ONLY=True`,
so there is no local sign-up page; OIDC sign-in is available only if you set the `OIDC_*` variables.

## Persistence

Database rows live in PostgreSQL (volume at `/var/lib/postgresql`, not `…/data`: Railway volumes contain
`lost+found`, which `initdb` refuses; `PGDATA=/var/lib/postgresql/pgdata` also stops local Docker shadowing it with
the image's anonymous `VOLUME`). Transaction attachments are files on the web service's volume.
