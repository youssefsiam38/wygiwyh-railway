#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2119
# Local end-to-end smoke test against a fresh compose stack (the stock image, pulled).
# Covers: migrations + admin created from env, the background worker, closed sign-up, auth and CSRF gates, admin login,
# the core finance flows (currency -> account -> transactions -> attachment), a web recreate, and logout.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

ADMIN=$TEST_TMP/admin.jar
cleanup() { [ "${KEEP_STACK:-0}" = 1 ] || compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"; }
trap cleanup EXIT

section "start-up"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_app || { compose logs --tail 80 web >&2; die "WYGIWYH never became reachable"; }
pass "the login page is served"
logs=$(compose logs --no-color web 2>&1)
assert_contains "the admin account was created from env" "Superuser '$WYG_ADMIN_EMAIL' created successfully" "$logs"
assert_not_contains "the admin password never reaches the logs" "$WYG_ADMIN_PASSWORD" "$logs"
assert_contains "the procrastinate worker is running" "Starting worker on all queues" "$logs"
assert_contains "gunicorn is serving" "Listening at: http://0.0.0.0:8000" "$logs"
assert_eq "the app processes run as the image's non-root user" "app" \
  "$(compose exec -T web sh -c 'for p in /proc/[0-9]*; do grep -q gunicorn $p/cmdline 2>/dev/null && stat -c %U $p && break; done' | tr -d '\r')"
assert_eq "the attachments volume belongs to the app user" "app" "$(compose exec -T web stat -c %U /usr/src/app/attachments | tr -d '\r')"
css=$(curl -s --max-time 30 "$APP_URL/login/" | grep -o '/static/[^"]*\.css' | head -1)
assert_eq "static files are served" "200" "$(http_code "$APP_URL$css")"

section "network exposure"
assert_eq "only the web service publishes a port" "web" \
  "$(compose config --format json | jq -r '[.services | to_entries[] | select(.value.ports) | .key] | join(" ")')"

section "security gates"
security_gates

section "admin"
if login "$WYG_ADMIN_EMAIL" "$WYG_ADMIN_PASSWORD" "$ADMIN"; then pass "admin signs in"; else fail "admin login: HTTP $CODE"; fi
csrf_gate "$ADMIN"

section "finance flows"
TAG=$(rand)
create_finance_data "$ADMIN" "$TAG"

section "web recreated"
compose up -d --force-recreate --no-deps web >/dev/null 2>&1 || die "web recreate failed"
sleep 3
wait_for_app || die "the app never came back after recreating web"
logs=$(compose logs --no-color web 2>&1 | tail -n 200)
assert_contains "the admin is not created twice" "already exists. Skipping creation" "$logs"
if login "$WYG_ADMIN_EMAIL" "$WYG_ADMIN_PASSWORD" "$ADMIN"; then pass "admin signs in after the restart"; else fail "admin login after restart: HTTP $CODE"; fi
verify_finance_data "$ADMIN" "$TAG"

section "logout"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -b "$ADMIN" -c "$ADMIN" "$APP_URL/logout/" || true)
assert_eq "logout" "302" "$code"
req "$ADMIN" GET /api/accounts/
assert_eq "the session is cleared" "401" "$CODE"

summary
