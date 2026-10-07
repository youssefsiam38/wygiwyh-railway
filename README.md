# WYGIWYH on Railway

One-click [Railway](https://railway.com) template for [WYGIWYH](https://github.com/eitchtee/WYGIWYH) ("What You Get
Is What You Have"), the self-hosted, multi-currency personal finance tracker: accounts, income and expenses, monthly
and yearly overviews, net worth, rules, a DCA tracker and a REST API.

Community-maintained; not affiliated with or endorsed by the WYGIWYH project. The icon in `assets/` is a generic
motif, not the WYGIWYH logo.

## What you get

| Service | Image | Public | Volume |
|---------|-------|--------|--------|
| `web` | `eitchtee/wygiwyh:0.23.2` (official, unmodified: gunicorn + procrastinate worker) | yes, port 8000 | `/usr/src/app/attachments` |
| `db`  | `postgres:15.19-bookworm` | no | `/var/lib/postgresql` |

Every image is pinned by digest; versions are in `UPSTREAM.md`. WYGIWYH is AGPL-3.0 and runs unmodified. No wrapper
image: the template only overrides the start command to hand the attachments volume to the image's `app` user.

## Deploy

1. Open https://railway.com/deploy/wygiwyh, click deploy and enter `ADMIN_EMAIL` (your email; it becomes the admin login).
2. Wait for both services to turn green (the first start runs the database migrations).
3. Open the `web` service → Variables → copy `ADMIN_PASSWORD`.
4. Open the `web` service's domain and sign in. Add other people under Users (admin only).

## Security

- There is no public sign-up: WYGIWYH only creates local accounts from env (`ADMIN_EMAIL`/`ADMIN_PASSWORD`) or by an
  admin in the app. OIDC is off unless you configure it. See `SECURITY.md`.
- HTTPS-aware: `HTTPS_ENABLED=true` (Secure session cookie, trusts Railway's `X-Forwarded-Proto`), `URL` and
  `DJANGO_ALLOWED_HOSTS` follow the Railway domain, a generated `SECRET_KEY`.
- PostgreSQL is private.

## Repository layout

| Path | Purpose |
|------|---------|
| `compose.yaml` | Local test topology mirroring the Railway services |
| `tests/` | `static.sh`, `smoke.sh`, `persistence.sh`, `railway-smoke.sh` (live, HTTPS) |
| `.github/workflows/test.yml` | static + smoke + persistence on every push |
| `marketplace/OVERVIEW.md` | Railway Marketplace page |
| `RAILWAY_TEMPLATE.md` | The exact published template configuration |

## Local development

```bash
tests/static.sh        # no containers
tests/smoke.sh         # admin from env, gates, finance flows, attachment upload, web recreate
tests/persistence.sh   # data and attachment survive down/up with volumes kept
```

The local stack serves on `http://127.0.0.1:18000` (`WYG_TEST_PORT` to change it), admin `admin@example.com` with a
placeholder password from `compose.yaml`. The tests read `WYG_TEST_ADMIN_*`, never a generic `ADMIN_PASSWORD` from
your shell.

## Licence

Template files: MIT (`LICENSE`). WYGIWYH: AGPL-3.0 (`licenses/WYGIWYH-LICENSE`). See `THIRD_PARTY_NOTICES.md`.
