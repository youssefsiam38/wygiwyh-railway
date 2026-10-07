#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2119
# Persistence: data (database rows and the attachment file) written before `compose down` (volumes kept) is still there
# after `compose up`, the admin can still sign in, and the admin is not re-created. Mirrors a Railway redeploy.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

ADMIN=$TEST_TMP/admin.jar
cleanup() { [ "${KEEP_STACK:-0}" = 1 ] || compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"; }
trap cleanup EXIT

section "write"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_app || die "WYGIWYH never became reachable"
login "$WYG_ADMIN_EMAIL" "$WYG_ADMIN_PASSWORD" "$ADMIN" || die "admin login failed: HTTP $CODE"
TAG=$(rand)
create_finance_data "$ADMIN" "$TAG"

section "recreate every service, keep volumes"
compose down >/dev/null 2>&1
compose up -d >/dev/null 2>&1 || die "compose up failed"
wait_for_app || die "WYGIWYH never came back"
pass "the stack came back"
assert_contains "the admin is not re-created on an existing database" "already exists. Skipping creation" "$(compose logs --no-color web 2>&1)"

section "verify"
if login "$WYG_ADMIN_EMAIL" "$WYG_ADMIN_PASSWORD" "$ADMIN"; then pass "admin still signs in"; else fail "admin login: HTTP $CODE"; fi
verify_finance_data "$ADMIN" "$TAG"
assert_eq "there is still no sign-up page" "404" "$(http_code "$APP_URL/auth/signup/")"

summary
