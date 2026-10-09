#!/usr/bin/env bash
# Checks a live sync server, e.g. right after a deploy (deploy-server.yml):
#
#   HEALTH_TOKEN=… scripts/server-smoke-test.sh <base-url> [<expected-rev>]
#
# 1. The expected code is live: right after a deploy, some requests still
#    reach the old version for a few seconds, so it waits until the new one
#    answers 3 times in a row (up to 2 minutes).
# 2. Secrets and Durable Object storage work (/v1/health/deep; a few tries,
#    for the same reason).
# 3. The public pages load, and sync without a token is refused with 401
#    (not a crash).
set -euo pipefail

base="${1:?usage: server-smoke-test.sh <base-url> [<expected-rev>]}"
rev="${2:-}"
: "${HEALTH_TOKEN:?HEALTH_TOKEN must be set}"

fail() {
  echo "::error::$*"
  exit 1
}

live=""
streak=0
for _ in $(seq 1 40); do
  live="$(curl -fsS --max-time 10 "$base/v1/health" | jq -r '.rev // empty' || true)"
  if [ -n "$live" ] && { [ -z "$rev" ] || [ "$live" = "$rev" ]; }; then
    streak=$((streak + 1))
    [ "$streak" -ge 3 ] && break
  else
    streak=0
  fi
  sleep 3
done
[ -n "$live" ] || fail "$base/v1/health doesn't answer"
[ "$streak" -ge 3 ] || fail "$base runs ${live:-nothing}, expected $rev"

deep=""
for _ in $(seq 1 6); do
  deep="$(curl -sS --max-time 20 -H "Authorization: Bearer $HEALTH_TOKEN" "$base/v1/health/deep" || true)"
  echo "$deep" | jq -e '.ok == true' >/dev/null 2>&1 && break
  sleep 5
done
echo "Deep health: $deep"
echo "$deep" | jq -e '.ok == true' >/dev/null 2>&1 || fail "deep health check failed"

for path in / /privacy; do
  curl -fsS -o /dev/null --max-time 10 "$base$path" || fail "GET $path failed"
done
code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 -X POST "$base/v1/sync" \
  -H 'content-type: application/json' -d '{}')"
[ "$code" = 401 ] || fail "POST /v1/sync without a token gave $code, expected 401"

echo "Smoke test passed: $base runs ${live}"
