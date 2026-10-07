# Security

## What the template enforces

- **No public sign-up.** WYGIWYH has no local registration page (`/auth/signup/` is 404). Accounts are created from
  env (the admin) or by an admin under Users.
- **No first-visitor race.** The admin is created by `manage.py setup_users` during start-up, before gunicorn
  listens, from `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD`.
- **HTTPS-correct Django.** `HTTPS_ENABLED=true` (Secure session cookie, proxy SSL header), `URL` (CSRF trusted
  origin) and `DJANGO_ALLOWED_HOSTS` pinned to the Railway domain, `DEBUG=false`, generated `SECRET_KEY`.
- **Private database.** PostgreSQL has no public domain or TCP proxy; its password is generated.
- **Non-root app.** Only the start command's `chown` runs as root; gunicorn and the worker run as `app`.

## What you should do

- Sign in and change the admin password (Settings). Changing `ADMIN_PASSWORD` after the first deploy has no effect;
  the account already exists. You may delete `ADMIN_EMAIL`/`ADMIN_PASSWORD` from the variables after the first
  sign-in, as upstream suggests.
- If you add OIDC, `OIDC_ALLOW_SIGNUP` defaults to `true`: anyone who can sign in at your identity provider gets an
  account. Set it to `false` unless that is what you want.
- Leave `OAUTH2_DCR_ENABLED` off (upstream default) unless remote MCP clients must self-register.
- Back up the `db` volume (Railway volume backups or `pg_dump`) and the `web` attachments volume.
- If you add a custom domain, add it to `DJANGO_ALLOWED_HOSTS` and `URL` (space-separated).

## Reporting

Template issues: https://github.com/youssefsiam38/wygiwyh-railway/issues. WYGIWYH vulnerabilities: report to the
upstream project privately (https://github.com/eitchtee/WYGIWYH/security).
