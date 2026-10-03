#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$REPO_ROOT/.tools"
OUTPUT="$REPO_ROOT/output"
WORK="${SULU_RECIPES_WORKDIR:-${TMPDIR:-/tmp}/sulu-recipes}"
ENDPOINT_PORT=8000
ENDPOINT_URL="http://127.0.0.1:$ENDPOINT_PORT/index.json"
OUR_REPO="github.com/mario-fehr/sulu-recipes"
SULU_LINE="${SULU_LINE:-3.0}"
LINE_FILE="$REPO_ROOT/tests/lines/$SULU_LINE.env"
if [ ! -f "$LINE_FILE" ]; then
  echo "no pin file $LINE_FILE for SULU_LINE=$SULU_LINE" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$LINE_FILE"

SYMFONY_RECIPES_SHA=64dab29
SYMFONY_RECIPES_CONTRIB_SHA=38fc43a

RECIPE_VENDORS="symfony scheb friendsofsymfony symfony-cmf doctrine sulu"
SUPERSEDED="symfony/framework-bundle symfony/security-bundle symfony/console symfony/twig-bundle scheb/2fa-bundle friendsofsymfony/jsrouting-bundle doctrine/doctrine-bundle"
SULU_YAML_PACKAGES="friendsofsymfony/rest-bundle jms/serializer-bundle league/flysystem-bundle stof/doctrine-extensions-bundle symfony/mailer symfony/messenger symfony/monolog-bundle symfony/routing symfony/translation"

mkdir -p "$WORK"
# PHP reports physical paths (/private/var/... on macOS); path normalization needs the same form.
WORK="$(cd "$WORK" && pwd -P)"

# Same as sulu/skeleton's own CI: translation cache warmup exceeds the default 128M.
mkdir -p "$WORK/php-ini"
echo "memory_limit=-1" > "$WORK/php-ini/zz-sulu-recipes.ini"
export PHP_INI_SCAN_DIR=":$WORK/php-ini"

upstream() {
  local name="$1" repo="$2" sha="${3:-}" dir="$WORK/clones/$1"
  if [ ! -d "$dir" ]; then
    if [ "$name" = sulu-skeleton ]; then
      git clone --quiet --no-checkout "https://github.com/$repo.git" "$dir"
    else
      git clone --quiet --no-checkout --filter=blob:none "https://github.com/$repo.git" "$dir"
    fi
  elif [ -z "$sha" ]; then
    git -C "$dir" fetch --quiet --tags --force origin
  fi
  [ -n "$sha" ] || return 0
  git -C "$dir" cat-file -e "$sha^{commit}" 2>/dev/null && return 0
  git -C "$dir" fetch --quiet origin "$sha" 2>/dev/null || git -C "$dir" fetch --quiet --tags --force origin || true
  git -C "$dir" cat-file -e "$sha^{commit}" 2>/dev/null || { echo "pin $sha not found in $repo" >&2; exit 1; }
}

skel_show() { git -C "$WORK/clones/sulu-skeleton" show "$SULU_SKELETON_SHA:$1"; }

SERVER_PIDS=""
CONTAINERS=""
cleanup() {
  for pid in $SERVER_PIDS; do kill "$pid" 2>/dev/null || true; done
  for c in $CONTAINERS; do docker rm -f "$c" >/dev/null 2>&1 || true; done
}
trap cleanup EXIT

require_free_port() {
  local rc=0
  curl -s -m 2 -o /dev/null "http://127.0.0.1:$1/" || rc=$?
  # 7: connection refused. Any other result, including a timeout or a non-HTTP reply, means something holds the port.
  if [ "$rc" != 7 ]; then
    echo "port $1 already answers; stop that server first" >&2
    return 1
  fi
}

serve() {
  local name="$1" port="$2" docroot="$3" router="${4:-}"
  require_free_port "$port"
  if [ -n "$router" ]; then
    php -S "127.0.0.1:$port" -t "$docroot" "$router" >"$WORK/$name.log" 2>&1 &
  else
    php -S "127.0.0.1:$port" -t "$docroot" >"$WORK/$name.log" 2>&1 &
  fi
  SERVER_PIDS="$SERVER_PIDS $!"
  for _ in $(seq 1 60); do
    curl -s -m 10 -o /dev/null "http://127.0.0.1:$port/" && return 0
    sleep 0.5
  done
  echo "$name server did not start, see $WORK/$name.log" >&2
  return 1
}

# sulu:admin:update-build overwrites assets/admin files that differ from the sulu/skeleton tag,
# which would hide a defect in the files the recipe shipped.
update_build_guarded() {
  local before after
  before="$(find assets/admin -path '*/node_modules' -prune -o -type f -exec shasum {} + | sort)"
  bin/adminconsole sulu:admin:update-build --no-interaction || return 1
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

lock_repo() { [ "$(jq -r --arg p "$1" '.[$p].recipe.repo' symfony.lock)" = "$2" ]; }
lock_version() { [ "$(jq -r --arg p "$1" '.[$p].recipe.version' symfony.lock)" = "$2" ]; }
lock_recipes() {
  jq -r 'to_entries[] | select(.value.recipe) | "\(.key) \(.value.recipe.version) \(.value.recipe.repo)"' symfony.lock \
    | sed "s|$OUR_REPO|<this repo>|" | sort
}
same_as_skeleton() { skel_show "$1" | cmp -s - "$1"; }

runtime_checks() {
  local db=sulu-recipes-mysql
  check "admin build present" test -f public/build/admin/manifest.json
  for console in adminconsole websiteconsole; do
    for env in dev prod test; do
      check "$console boots in $env" env APP_ENV="$env" "bin/$console" cache:clear
      check "$console container in $env" env APP_ENV="$env" "bin/$console" debug:container --env-vars
    done
  done
  CONTAINERS="$CONTAINERS $db"
  docker rm -f "$db" >/dev/null 2>&1 || true
  docker run -d --name "$db" -e MYSQL_ROOT_PASSWORD=ChangeMe -p 3307:3306 mysql:8.4 >/dev/null
  # mysqladmin ping already answers the init-phase server, which has no TCP; wait for a TCP connection.
  for _ in $(seq 1 90); do docker exec "$db" mysql -h 127.0.0.1 -uroot -pChangeMe -e "SELECT 1" >/dev/null 2>&1 && break; sleep 1; done
  echo 'DATABASE_URL="mysql://root:ChangeMe@127.0.0.1:3307/sulu_recipes?serverVersion=8.4&charset=utf8mb4"' > .env.local
  check "sulu:build dev" bin/adminconsole sulu:build dev --no-interaction
  serve web 8001 public config/router.php
  check "/admin answers 200 with the Sulu admin" sh -c 'curl -fsL http://127.0.0.1:8001/admin | grep -qi sulu'
  check "homepage renders the content block" sh -c 'curl -fs http://127.0.0.1:8001/ | grep -q "<h1>"'
}
