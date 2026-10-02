#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REFS="$REPO_ROOT/.references"
TOOLS="$REPO_ROOT/.tools"
OUTPUT="$REPO_ROOT/output"
WORK="${SULU_RECIPES_WORKDIR:-${TMPDIR:-/tmp}/sulu-recipes}"
ENDPOINT_PORT=8000
ENDPOINT_URL="http://127.0.0.1:$ENDPOINT_PORT/index.json"
OUR_REPO="github.com/mario-fehr/sulu-recipes"

SULU_SKELETON_SHA=336f7ba
SYMFONY_RECIPES_SHA=64dab29
SYMFONY_RECIPES_CONTRIB_SHA=38fc43a
SULU_SKELETON_VERSION=3.0.10

RECIPE_VENDORS="symfony scheb friendsofsymfony symfony-cmf doctrine sulu"
SUPERSEDED="symfony/framework-bundle symfony/security-bundle symfony/console symfony/twig-bundle scheb/2fa-bundle friendsofsymfony/jsrouting-bundle doctrine/doctrine-bundle"

mkdir -p "$WORK"
# PHP reports physical paths (/private/var/... on macOS); path normalization needs the same form.
WORK="$(cd "$WORK" && pwd -P)"

# Same as sulu/skeleton's own CI: translation cache warmup exceeds the default 128M.
mkdir -p "$WORK/php-ini"
echo "memory_limit=-1" > "$WORK/php-ini/zz-sulu-recipes.ini"
export PHP_INI_SCAN_DIR=":$WORK/php-ini"

skel_show() { git -C "$REFS/sulu-skeleton" show "$SULU_SKELETON_SHA:$1"; }

start_endpoint() {
  if curl -fs "$ENDPOINT_URL" >/dev/null 2>&1; then
    echo "port $ENDPOINT_PORT already serves an endpoint; stop it first" >&2
    return 1
  fi
  php -S "127.0.0.1:$ENDPOINT_PORT" -t "$OUTPUT" >"$WORK/endpoint.log" 2>&1 &
  ENDPOINT_PID=$!
  trap 'kill "$ENDPOINT_PID" 2>/dev/null || true' EXIT
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    curl -fs "$ENDPOINT_URL" >/dev/null 2>&1 && return 0
    sleep 0.5
  done
  echo "endpoint did not start, see $WORK/endpoint.log" >&2
  return 1
}

# sulu:admin:update-build overwrites assets/admin files that differ from the sulu/skeleton tag,
# which would hide a defect in the files the recipe shipped.
update_build_guarded() {
  local before after
  before="$(find assets/admin -path '*/node_modules' -prune -o -type f -exec shasum {} + | sort)"
  bin/adminconsole sulu:admin:update-build --no-interaction
  after="$(find assets/admin -path '*/node_modules' -prune -o -type f -exec shasum {} + | sort)"
  if [ "$before" != "$after" ]; then
    echo "sulu:admin:update-build changed recipe-shipped assets/admin files:" >&2
    diff <(echo "$before") <(echo "$after") >&2 || true
    return 1
  fi
}

FAILURES=0
check() {
  local name="$1"; shift
  if "$@" >>"$WORK/checks.log" 2>&1; then echo "PASS $name"; else echo "FAIL $name"; FAILURES=$((FAILURES + 1)); fi
}

finish() {
  echo "$FAILURES failure(s); details in $WORK/checks.log"
  [ "$FAILURES" -eq 0 ]
}
