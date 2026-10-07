#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2119
# Static validation: syntax, shellcheck, compose shape, image pins and security defaults. No containers started.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
cd "$REPO_ROOT"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

section "syntax"
for f in tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "parses: $f"; else fail "syntax error: $f"; fi
done

section "shellcheck"
if command -v shellcheck >/dev/null; then
  if shellcheck -x -s bash tests/*.sh; then pass "shellcheck bash"; else fail "shellcheck bash"; fi
else
  echo "  SKIP  shellcheck not installed"
fi

section "compose"
if docker compose -f compose.yaml config -q; then pass "compose config"; else fail "compose config"; fi
cfg=$(docker compose -f compose.yaml config --format json)
web() { jq -r ".services.web.$1" <<<"$cfg"; }
assert_eq "two services" "db web" "$(jq -r '[.services | keys[]] | sort | join(" ")' <<<"$cfg")"
assert_eq "only the web service publishes a port" "web" "$(jq -r '[.services | to_entries[] | select(.value.ports) | .key] | join(" ")' <<<"$cfg")"
assert_eq "the port binds to loopback" "127.0.0.1" "$(jq -r '[.services.web.ports[]? | .host_ip] | join(" ")' <<<"$cfg")"
assert_eq "the published port is the app's \$PORT" "$(web environment.PORT)" "$(jq -r '[.services.web.ports[]? | .target] | join(" ")' <<<"$cfg")"
assert_eq "gunicorn's INTERNAL_PORT equals PORT" "$(web environment.PORT)" "$(web environment.INTERNAL_PORT)"
assert_contains "WYGIWYH is pinned by version tag and digest" '^eitchtee/wygiwyh:[0-9][0-9.]*@sha256:[0-9a-f]\{64\}$' "$(web image)"
assert_contains "postgres is pinned by tag and digest" '^postgres:15\.[0-9]*-bookworm@sha256:[0-9a-f]\{64\}$' "$(jq -r '.services.db.image' <<<"$cfg")"
assert_eq "the database volume is mounted at the parent dir" "/var/lib/postgresql" "$(jq -r '[.services.db.volumes[]? | .target] | join(" ")' <<<"$cfg")"
assert_eq "PGDATA lives inside the volume" "/var/lib/postgresql/pgdata" "$(jq -r '.services.db.environment.PGDATA' <<<"$cfg")"
assert_eq "the attachments volume" "/usr/src/app/attachments" "$(jq -r '[.services.web.volumes[]? | .target] | join(" ")' <<<"$cfg")"
assert_eq "web starts as root (RAILWAY_RUN_UID=0 on Railway)" "0" "$(web user)"
assert_eq "the start command chowns the volume, then runs the stock entrypoint" \
  "chown -R app:app /usr/src/app/attachments && exec /start-single" "$(jq -r '.services.web.command[-1]' <<<"$cfg")"
assert_eq "DEBUG is off" "false" "$(web environment.DEBUG)"
assert_eq "admin email from env" "admin@example.com" "$(web environment.ADMIN_EMAIL)"
assert_contains "the compose admin password is a placeholder" 'local-test-only' "$(web environment.ADMIN_PASSWORD)"
assert_contains "the compose secret key is a placeholder" 'local-test-only' "$(web environment.SECRET_KEY)"
assert_contains "the compose DB password is a placeholder" 'local-test-only' "$(jq -r '.services.db.environment.POSTGRES_PASSWORD' <<<"$cfg")"
assert_eq "web and db agree on the DB password" "$(jq -r '.services.db.environment.POSTGRES_PASSWORD' <<<"$cfg")" "$(web environment.SQL_PASSWORD)"
assert_eq "no OIDC is configured (it would allow sign-up)" "" "$(web 'environment.OIDC_CLIENT_ID // empty')"

section "secrets hygiene"
mapfile -t tracked < <(git ls-files 2>/dev/null | grep . || find . -type f -not -path './.git/*' -not -path './test-output/*')
if [ "${#tracked[@]}" -gt 0 ] && grep -lE '(sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "${tracked[@]}" 2>/dev/null; then
  fail "a credential-shaped string is in the repository"
else
  pass "no credential-shaped strings in ${#tracked[@]} files"
fi

summary
