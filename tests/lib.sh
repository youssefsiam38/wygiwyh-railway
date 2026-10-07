#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2034,SC2120
# Shared helpers for wygiwyh-railway tests. Source this file; do not execute it.
# Secrets are never echoed. Only names, counts, and pass/fail results are printed.

: "${APP_URL:=http://127.0.0.1:${WYG_TEST_PORT:-18000}}"
: "${TEST_TIMEOUT:=600}"
# Do not inherit a generic ADMIN_EMAIL/ADMIN_PASSWORD from the caller's shell; tests use their own names.
: "${WYG_ADMIN_EMAIL:=${WYG_TEST_ADMIN_EMAIL:-admin@example.com}}"
: "${WYG_ADMIN_PASSWORD:=${WYG_TEST_ADMIN_PASSWORD:-local-test-only-admin-password}}"

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
chmod 700 "$TEST_TMP"
export TEST_TMP
_PASS=0; _FAIL=0
CODE=""; BODY=""

pass() { _PASS=$((_PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { _FAIL=$((_FAIL+1)); printf '  FAIL  %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$*"; }
summary() { printf '\n%d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

assert_eq() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1: expected [$2] got [$3]"; fi; }
assert_contains() { if grep -q -- "$2" <<<"$3"; then pass "$1"; else fail "$1: missing [$2]"; fi; }
assert_not_contains() { if grep -qF -- "$2" <<<"$3"; then fail "$1: found forbidden value"; else pass "$1"; fi; }

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$@" || true; }

wait_for_code() {
  local url=$1 want=$2 timeout=${3:-$TEST_TIMEOUT} start code
  start=$(date +%s)
  while :; do
    code=$(http_code "$url")
    [ "$code" = "$want" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for %s -> %s (last %s)\n' "$url" "$want" "$code" >&2; return 1; fi
    sleep 3
  done
}

# The app is up once the (public) login page renders.
wait_for_app() { wait_for_code "$APP_URL/login/" 200 "${1:-$TEST_TIMEOUT}"; }

compose() { docker compose -f "$REPO_ROOT/compose.yaml" "$@"; }

csrf_of() { awk '$6=="csrftoken"{print $7}' "$1" | tail -1; }

# req JAR METHOD PATH [JSON] [extra curl args...] -> sets CODE and BODY. JAR may be "" (anonymous).
# With a JAR, Django's CSRF token and a same-origin Referer are sent, as the browser does.
req() {
  local jar=$1 method=$2 path=$3 data=${4:-}
  shift 3; [ $# -gt 0 ] && shift
  local args=(-s -o "$TEST_TMP/body" -w '%{http_code}' --max-time 60 -X "$method" -H 'Accept: application/json'
              -H "Referer: $APP_URL/")
  if [ -n "$jar" ]; then
    args+=(-b "$jar" -c "$jar")
    [ "$method" = GET ] || args+=(-H "X-CSRFToken: $(csrf_of "$jar")")
  fi
  [ -n "$data" ] && args+=(-H 'Content-Type: application/json' --data "$data")
  CODE=$(curl "${args[@]}" "$@" "$APP_URL$path" || true)
  BODY=$(cat "$TEST_TMP/body" 2>/dev/null || true)
}

# login EMAIL PASSWORD JAR -> 0 on success. Django form login: GET /login/ for the CSRF cookie, then POST the form.
# The form body (with the password) goes through a mode-600 file, never argv. Success is a 302 away from /login/.
login() {
  local email=$1 pw=$2 jar=$3 tok
  rm -f "$jar"
  curl -s -o /dev/null --max-time 30 -c "$jar" "$APP_URL/login/" || true
  tok=$(csrf_of "$jar")
  ( umask 077
    printf 'csrfmiddlewaretoken=%s&username=%s&password=%s' "$tok" \
      "$(jq -rn --arg v "$email" '$v|@uri')" "$(jq -rn --arg v "$pw" '$v|@uri')" >"$TEST_TMP/login.form" )
  CODE=$(curl -s -o "$TEST_TMP/body" -w '%{http_code}' --max-time 60 -b "$jar" -c "$jar" \
    -H "Referer: $APP_URL/login/" --data "@$TEST_TMP/login.form" "$APP_URL/login/" || true)
  rm -f "$TEST_TMP/login.form"
  [ "$CODE" = "302" ] && grep -q 'sessionid' "$jar"
}

rand() { head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

# create_finance_data JAR TAG -> creates a currency, an account, two transactions and an attachment named after TAG,
# asserting each step. Leaves CUR_ID, ACCOUNT_ID, TX_ID and ATT_ID set.
create_finance_data() {
  local jar=$1 tag=$2 today month
  today=$(date -u +%F); month=$(date -u +%Y-%m-01)

  req "$jar" POST /api/currencies/ "$(jq -nc --arg n "Test Coin $tag" '{code:"TST", name:$n, decimal_places:2, prefix:"T$ "}')"
  assert_eq "create a currency" "201" "$CODE"
  CUR_ID=$(jq -r '.id // empty' <<<"$BODY")

  req "$jar" POST /api/accounts/ "$(jq -nc --arg n "Checking $tag" --argjson c "${CUR_ID:-0}" \
    '{name:$n, currency_id:$c, group_id:null, exchange_currency_id:null, is_asset:false}')"
  assert_eq "create an account" "201" "$CODE"
  ACCOUNT_ID=$(jq -r '.id // empty' <<<"$BODY")

  req "$jar" POST /api/transactions/ "$(jq -nc --argjson a "${ACCOUNT_ID:-0}" --arg d "$today" --arg r "$month" --arg s "Salary $tag" \
    '{account_id:$a, type:"IN", date:$d, reference_date:$r, amount:"1000.00", description:$s, is_paid:true}')"
  assert_eq "create an income transaction" "201" "$CODE"
  req "$jar" POST /api/transactions/ "$(jq -nc --argjson a "${ACCOUNT_ID:-0}" --arg d "$today" --arg r "$month" --arg s "Groceries $tag" \
    '{account_id:$a, type:"EX", date:$d, reference_date:$r, amount:"42.50", description:$s, notes:"railway template test", is_paid:true}')"
  assert_eq "create an expense transaction" "201" "$CODE"
  TX_ID=$(jq -r '.id // empty' <<<"$BODY")

  # Attachments are stored on the web service's volume (/usr/src/app/attachments). Upload one through the UI endpoint.
  printf 'receipt for %s\n' "$tag" >"$TEST_TMP/receipt-$tag.txt"
  CODE=$(curl -s -o "$TEST_TMP/body" -w '%{http_code}' --max-time 60 -b "$jar" -c "$jar" -H 'HX-Request: true' \
    -H "X-CSRFToken: $(csrf_of "$jar")" -H "Referer: $APP_URL/" \
    -F "attachments=@$TEST_TMP/receipt-$tag.txt;type=text/plain" "$APP_URL/transaction/${TX_ID:-0}/attachments/" || true)
  assert_eq "upload a receipt attachment" "200" "$CODE"
  verify_finance_data "$jar" "$tag"
}

# verify_finance_data JAR TAG -> the data created by create_finance_data(TAG) is all there, including the file.
verify_finance_data() {
  local jar=$1 tag=$2 got
  req "$jar" GET "/api/currencies/?page_size=500"
  CUR_ID=$(jq -r --arg n "Test Coin $tag" '[.results[] | select(.name==$n) | .id][0] // empty' <<<"$BODY")
  [ -n "$CUR_ID" ] && pass "the currency is listed" || fail "the currency is not listed"
  req "$jar" GET "/api/accounts/?page_size=500"
  ACCOUNT_ID=$(jq -r --arg n "Checking $tag" '[.results[] | select(.name==$n) | .id][0] // empty' <<<"$BODY")
  [ -n "$ACCOUNT_ID" ] && pass "the account is listed" || fail "the account is not listed"
  assert_eq "the account uses the currency" "TST" "$(jq -r --arg n "Checking $tag" '[.results[] | select(.name==$n) | .currency.code][0]' <<<"$BODY")"
  req "$jar" GET "/api/transactions/?account=${ACCOUNT_ID:-0}&page_size=500"
  assert_eq "both transactions are listed" "2" "$(jq '.results | length' <<<"$BODY")"
  assert_eq "the expense amount, in cents" "4250" "$(jq -r --arg s "Groceries $tag" '[.results[] | select(.description==$s) | .amount][0] | tonumber * 100 | round' <<<"$BODY")"
  TX_ID=$(jq -r --arg s "Groceries $tag" '[.results[] | select(.description==$s) | .id][0] // empty' <<<"$BODY")
  CODE=$(curl -s -o "$TEST_TMP/body" -w '%{http_code}' --max-time 60 -b "$jar" -H 'HX-Request: true' \
    "$APP_URL/transaction/${TX_ID:-0}/attachments/list/" || true)
  ATT_ID=$(grep -o 'attachments/[0-9a-f-]\{36\}/download' "$TEST_TMP/body" | head -1 | cut -d/ -f2)
  [ -n "$ATT_ID" ] && pass "the attachment is listed" || fail "the attachment is not listed (HTTP $CODE)"
  got=$(curl -s --max-time 60 -b "$jar" "$APP_URL/transaction/attachments/${ATT_ID:-none}/download/" || true)
  assert_eq "the attachment file downloads intact" "receipt for $tag" "$got"
  CODE=$(curl -s -o /dev/null -w '%{http_code} %{url_effective}' -L --max-time 60 -b "$jar" "$APP_URL/" || true)
  assert_contains "the monthly overview renders" '^200 .*/monthly/' "$CODE"
}

# security_gates -> anonymous access is refused, sign-up is closed, wrong passwords are rejected, CSRF is enforced.
security_gates() {
  local loc
  loc=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 30 "$APP_URL/" || true)
  assert_contains "anonymous / redirects to the login page" '^302 .*/login/' "$loc"
  req "" GET /api/accounts/
  assert_eq "anonymous /api/accounts/ is refused" "401" "$CODE"
  req "" GET /api/transactions/
  assert_eq "anonymous /api/transactions/ is refused" "401" "$CODE"
  assert_eq "the Django admin requires a login" "302" "$(http_code "$APP_URL/admin/")"
  assert_eq "there is no sign-up page (/auth/signup/)" "404" "$(http_code "$APP_URL/auth/signup/")"
  assert_not_contains "the login page offers no sign-up" "signup" "$(curl -s --max-time 30 "$APP_URL/login/")"
  if login "intruder-$(rand)@example.com" "intruder-password-123" "$TEST_TMP/intruder.jar"; then
    fail "an unknown user can sign in"
  else
    assert_eq "an unknown user cannot sign in (form re-rendered)" "200" "$CODE"
  fi
  if login "$WYG_ADMIN_EMAIL" "not-the-password" "$TEST_TMP/wrong.jar"; then
    fail "a wrong admin password is accepted"
  else
    assert_eq "a wrong admin password is rejected" "200" "$CODE"
  fi
  ( umask 077; printf 'user = "%s:not-the-password"\n' "$WYG_ADMIN_EMAIL" >"$TEST_TMP/basic.cfg" )
  assert_eq "API basic auth with a wrong password is refused" "401" "$(http_code -K "$TEST_TMP/basic.cfg" "$APP_URL/api/accounts/")"
}

# csrf_gate JAR -> a signed-in session without the CSRF token cannot write.
csrf_gate() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -b "$1" -H "Referer: $APP_URL/" -H 'Content-Type: application/json' \
    --data '{"code":"BAD","name":"no csrf"}' "$APP_URL/api/currencies/" || true)
  assert_eq "a session write without the CSRF token is refused" "403" "$code"
}
