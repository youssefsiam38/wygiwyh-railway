#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016,SC2119
# Live end-to-end test against a deployed template, over HTTPS.
#
#   APP_URL=https://<domain> WYG_ADMIN_EMAIL=<ADMIN_EMAIL> WYG_ADMIN_PASSWORD_FILE=<file holding ADMIN_PASSWORD> \
#     STATE_FILE=/tmp/wyg-live.tag tests/railway-smoke.sh            # full run; records the tag of what it created
#   ... tests/railway-smoke.sh --verify                              # after a redeploy: is it all still there?
#
# Never prints the password or cookies.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
[ -n "${APP_URL:-}" ] || { echo "set APP_URL=https://<your-domain>" >&2; exit 2; }
[ -n "${WYG_ADMIN_EMAIL:-}" ] || { echo "set WYG_ADMIN_EMAIL (the template's ADMIN_EMAIL)" >&2; exit 2; }
[ -n "${WYG_ADMIN_PASSWORD_FILE:-}" ] && WYG_ADMIN_PASSWORD=$(cat "$WYG_ADMIN_PASSWORD_FILE")
[ -n "${WYG_ADMIN_PASSWORD:-}" ] || { echo "set WYG_ADMIN_PASSWORD_FILE" >&2; exit 2; }
APP_URL=${APP_URL%/}
: "${STATE_FILE:=$(mktemp)}"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

ADMIN=$TEST_TMP/admin.jar
MODE=${1:-full}

section "edge"
assert_eq "HTTPS login page" "200" "$(http_code "$APP_URL/login/")"
css=$(curl -s --max-time 30 "$APP_URL/login/" | grep -o '/static/[^"]*\.css' | head -1)
assert_eq "static files over HTTPS" "200" "$(http_code "$APP_URL$css")"
case "$APP_URL" in
  https://*) assert_eq "plain HTTP is redirected to HTTPS" "301" "$(http_code "http://${APP_URL#https://}/login/")" ;;
esac

section "security gates"
security_gates

section "admin"
if login "$WYG_ADMIN_EMAIL" "$WYG_ADMIN_PASSWORD" "$ADMIN"; then pass "admin signs in over HTTPS (Django CSRF + Referer check)"; else fail "admin login: HTTP $CODE"; fi
case "$APP_URL" in
  https://*) assert_eq "the session cookie is Secure" "TRUE" "$(awk '$6=="sessionid"{print $4}' "$ADMIN" | tail -1)" ;;
esac
csrf_gate "$ADMIN"

if [ "$MODE" = "--verify" ]; then
  TAG=$(cat "$STATE_FILE")
  [ -n "$TAG" ] || die "no tag in $STATE_FILE"
  section "data survived"
  verify_finance_data "$ADMIN" "$TAG"
else
  section "finance flows"
  TAG=$(rand)
  create_finance_data "$ADMIN" "$TAG"
  printf '%s\n' "$TAG" >"$STATE_FILE"
fi

summary
