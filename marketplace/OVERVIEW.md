# Deploy and Host WYGIWYH on Railway

WYGIWYH ("What You Get Is What You Have") is an open-source, self-hosted personal finance tracker built around a
simple rule: spend what you earn this month, and treat savings as untouchable. It tracks income and expenses across
many accounts and currencies, with monthly and yearly overviews, net worth, rules, a DCA tracker and a REST API.
This template deploys it ready for the internet: your admin account is created from the email you enter and a
generated password, and there is no public sign-up. It is a community-maintained template and is not affiliated
with the WYGIWYH project.

## About Hosting WYGIWYH

WYGIWYH is a Django app. The official image runs gunicorn and a procrastinate background worker (recurring
transactions, automatic exchange rates, cleanup) in one container, backed by PostgreSQL. This template deploys that
image unmodified as one public `web` service plus a private PostgreSQL 15 with its own volume; transaction
attachments are kept on a volume on `web`.

Running Django behind Railway's HTTPS proxy needs a few settings to line up, and they are all wired for you: the
trusted CSRF origin and allowed hosts follow your Railway domain (including Railway's health-check host), the
session cookie is Secure and the proxy's HTTPS header is trusted, and the secret key is generated. Railway mounts
volumes as root while the image runs as a non-root user, so the start command hands the attachments volume to that
user before starting the image's own process manager; the app never runs as root.

## Common Use Cases

- Track income, expenses and balances across bank accounts, cards, wallets and investments in one place
- Manage money in several currencies, including custom ones for crypto or reward points, with automatic exchange rates
- Follow monthly and yearly totals and net worth without the constraints of a budgeting app
- Automate entries from other tools through the REST API or rules

## Dependencies for WYGIWYH Hosting

- PostgreSQL 15: included, on Railway's private network, with its own volume
- Optional: an OIDC provider for single sign-on

### Deployment Dependencies

- WYGIWYH (AGPL-3.0): https://github.com/eitchtee/WYGIWYH
- Template source and tests: https://github.com/youssefsiam38/wygiwyh-railway

### Implementation Details

**First sign-in:** enter your email as `ADMIN_EMAIL` when deploying. After the deploy turns green, open the `web`
service's Variables, copy `ADMIN_PASSWORD`, and sign in at the `web` service's domain. Change the password in
WYGIWYH's settings; the variable is only used to create the account. Add other people under Users.

**What's configured for you:** the official `eitchtee/wygiwyh` image pinned by version and digest and used
unmodified; database migrations and the admin account on every start (the admin is created once); the background
worker; a generated `SECRET_KEY` and PostgreSQL password; `URL`, `DJANGO_ALLOWED_HOSTS` and `HTTPS_ENABLED` for
Railway's domain; a health check on `/login/`; volumes for the database and for attachments.

**Optional settings** on `web`: `OIDC_CLIENT_NAME`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_SERVER_URL` for
single sign-on (set `OIDC_ALLOW_SIGNUP=false` unless everyone at your provider should get an account);
`ENABLE_SOFT_DELETE` and `KEEP_DELETED_ENTRIES_FOR`; `WEB_CONCURRENCY`, `TASK_WORKERS`; `TZ`. If you add a
custom domain, append it to `DJANGO_ALLOWED_HOSTS` and `URL`.

Tested on a live deployment of this template over HTTPS: admin sign-in through Django's CSRF-protected form,
refused anonymous and wrong-password access, no sign-up page, creating a currency, an account, transactions and a
file attachment, and all of it surviving a redeploy.

## Why Deploy WYGIWYH on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you
don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying WYGIWYH on Railway, you are one step closer to supporting a complete full-stack application with
minimal burden. Host your servers, databases, AI agents, and more on Railway.
