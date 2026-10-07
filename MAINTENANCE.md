# Maintenance

## Bumping WYGIWYH

1. Resolve the new digest (`UPSTREAM.md`); update `compose.yaml` and `UPSTREAM.md`.
2. Check upstream's `docker/prod/` scripts, `.env.example` and `app/WYGIWYH/settings.py` for changes (new env vars,
   a changed `start-single`, a new process in `supervisord.conf`, the attachments path).
3. `tests/static.sh && tests/smoke.sh && tests/persistence.sh`.
4. Update `_audit/spec_wygiwyh.py`, run `tplkit.patch_template` against the template id in `RAILWAY_TEMPLATE.md`,
   deploy a clean-room copy and run `tests/railway-smoke.sh` (full, redeploy, `--verify`).

## Rebuilding the template from scratch

`spec_wygiwyh.py` + `tplkit.skeleton` → `railway templates create` → `tplkit.patch_template` → verify. Only the
skeleton sets volumes, domains and health checks.

## Gotchas specific to this template

- `DJANGO_ALLOWED_HOSTS` must include `healthcheck.railway.app`, or Django answers Railway's health check with 400
  and the deploy fails.
- The health check path is `/login/` (with the slash; `/login` is a 301).
- `PORT` and `INTERNAL_PORT` must match (gunicorn binds `INTERNAL_PORT`; Railway routes and health-checks `PORT`).
- The image's `USER app` cannot write a root-owned Railway volume: keep `RAILWAY_RUN_UID=0` and the `chown` start
  command. supervisord drops the app processes to `app`.
- gunicorn logs `Control server error: [Errno 13] Permission denied: '/root/.gunicorn'` at start (HOME stays
  `/root` after supervisord switches user). It is gunicorn 26's optional control socket and harmless.
- Locally `HTTPS_ENABLED=false` (plain http; a Secure cookie would not be sent). The template sets `true`.
- PostgreSQL: volume at `/var/lib/postgresql`, `PGDATA=/var/lib/postgresql/pgdata`.
- Tests use `WYG_TEST_ADMIN_*`/`WYG_ADMIN_*`, never a generic `ADMIN_PASSWORD` inherited from the shell.
- Upstream `.env.example` names `KEEP_DELETED_TRANSACTIONS_FOR`, but `settings.py` reads `KEEP_DELETED_ENTRIES_FOR`;
  the template exposes the one the code reads.
