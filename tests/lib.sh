#!/usr/bin/env bash
# Shared setup for every harness script: loads tests/lines/$SULU_LINE.env and tests/pins.env, prepares the work directory and defines the helpers.
# Env: SULU_LINE SULU_RECIPES_WORKDIR SULU_RECIPES_REPO SULU_PHP SULU_MYSQL_VERSION
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$REPO_ROOT/.tools"
OUTPUT="$REPO_ROOT/output"
WORK="${SULU_RECIPES_WORKDIR:-${TMPDIR:-/tmp}/sulu-recipes}"
ENDPOINT_PORT=8000
ENDPOINT_URL="http://127.0.0.1:$ENDPOINT_PORT/index.json"
if [ -z "${SULU_RECIPES_REPO:-}" ]; then
  SULU_RECIPES_REPO="$({ git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true; } | sed -E 's#^(https://github\.com/|ssh://git@github\.com/|git@github\.com:)##; s#\.git$##')"
fi
OUR_REPO="github.com/$SULU_RECIPES_REPO"
require_repo_name() {
  if ! [[ "$SULU_RECIPES_REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "cannot derive owner/repo from origin; set SULU_RECIPES_REPO" >&2
    exit 1
  fi
}
SULU_LINE="${SULU_LINE:-3.0}"
LINE_FILE="$REPO_ROOT/tests/lines/$SULU_LINE.env"
if [ ! -f "$LINE_FILE" ]; then
  echo "no pin file $LINE_FILE for SULU_LINE=$SULU_LINE" >&2
  exit 1
fi
unset SULU_BARE_REQUIRE SULU_BARE_REQUIRE_DEV SULU_BARE_LOWEST_FLOOR SULU_PARITY_CONFIG
# shellcheck source=/dev/null
source "$LINE_FILE"
if [ -n "${SULU_PHP:-}" ]; then
  php_running="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
  if [ "$php_running" != "$SULU_PHP" ]; then
    echo "SULU_PHP=$SULU_PHP, but php is $php_running" >&2
    exit 1
  fi
fi

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/pins.env"

RECIPE_VENDORS="symfony scheb friendsofsymfony symfony-cmf doctrine sulu phpstan rector php-cs-fixer vincentlanglet"
SUPERSEDED="symfony/framework-bundle symfony/security-bundle symfony/console symfony/twig-bundle scheb/2fa-bundle friendsofsymfony/jsrouting-bundle doctrine/doctrine-bundle symfony/web-profiler-bundle doctrine/phpcr-bundle symfony/form phpstan/phpstan php-cs-fixer/shim vincentlanglet/twig-cs-fixer"
SULU_YAML_PACKAGES="friendsofsymfony/rest-bundle jms/serializer-bundle league/flysystem-bundle stof/doctrine-extensions-bundle symfony/mailer symfony/messenger symfony/monolog-bundle symfony/routing symfony/translation"
OWN_RECIPES="symfony-cmf/routing-bundle phpstan/phpstan-doctrine phpstan/phpstan-symfony phpstan/extension-installer rector/rector"
TOOLING_FILES="phpstan.dist.neon tests/phpstan/object-manager.php tests/phpstan/console-application.php .php-cs-fixer.dist.php .twig-cs-fixer.dist.php rector.php tests/rector/symfony-container.php"

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
PATCH_ROOT="$REPO_ROOT/tests/patches"
recipe_dirs() {
  local v d
  for v in $RECIPE_VENDORS; do
    for d in "$1/$v"/*/*; do
      if [ -f "$d/manifest.json" ]; then echo "${d#"$1"/}"; fi
    done
  done
}
recipe_files() { (cd "$1/$2" && find . -type f ! -name manifest.json ! -name post-install.txt | sed 's|^\./||' | sort); }
rebuild_file() {
  local recipe="$1" path="$2" ref="$3" tmp kind err rc=0 n=1
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/$(dirname "$path")"
  if ! git -C "$WORK/clones/${4:-sulu-skeleton}" show "$ref:${5:-$path}" >"$tmp/$path" 2>/dev/null; then
    echo "${4:-sulu-skeleton} has no ${5:-$path} at $ref" >&2
    rm -rf "$tmp"
    return 1
  fi
  for kind in fix adapt; do
    n=$((n + 1))
    [ -f "$PATCH_ROOT/$recipe/$path.$kind.patch" ] || continue
    if ! err="$(cd "$tmp" && git apply "$PATCH_ROOT/$recipe/$path.$kind.patch" 2>&1)"; then
      echo "$kind patch of $recipe/$path does not apply at $ref: ${err//$'\n'/; }" >&2
      rc=$n
      break
    fi
  done
  if [ "$rc" = 0 ]; then cat "$tmp/$path"; fi
  rm -rf "$tmp"
  return "$rc"
}
official_clones() {
  if [ -z "${SYMFONY_RECIPES_SHA:-}" ] || [ -z "${SYMFONY_RECIPES_CONTRIB_SHA:-}" ]; then
    echo "tests/pins.env must set SYMFONY_RECIPES_SHA and SYMFONY_RECIPES_CONTRIB_SHA" >&2
    exit 1
  fi
  upstream symfony-recipes symfony/recipes "$SYMFONY_RECIPES_SHA"
  upstream symfony-recipes-contrib symfony/recipes-contrib "$SYMFONY_RECIPES_CONTRIB_SHA"
}
skeleton_pins() {
  local f
  for f in "$REPO_ROOT"/tests/lines/*.env; do
    upstream sulu-skeleton sulu/skeleton "$(sed -n 's/^SULU_SKELETON_SHA=//p' "$f")"
  done
}
official_origin() {
  local pkg="${1%/*}" v="${1##*/}" clone sha best
  case " $SUPERSEDED " in *" $pkg "*) ;; *) return 0 ;; esac
  for clone in symfony-recipes symfony-recipes-contrib; do
    if [ "$clone" = symfony-recipes ]; then sha="${2:-$SYMFONY_RECIPES_SHA}"; else sha="${2:-$SYMFONY_RECIPES_CONTRIB_SHA}"; fi
    if ! git -C "$WORK/clones/$clone" cat-file -e "$sha^{commit}" 2>/dev/null; then
      echo "$clone has no commit $sha; run official_clones first" >&2
      return 1
    fi
    best="$(git -C "$WORK/clones/$clone" ls-tree --name-only "$sha" "$pkg/" | sed "s#^$pkg/##" | while IFS= read -r x; do
      if [ "$(printf '%s\n' "$x" "$v" | sort -V | head -n 1)" = "$x" ]; then echo "$x"; fi
    done | sort -V | tail -n 1)"
    if [ -n "$best" ]; then echo "$clone $sha $pkg/$best"; return 0; fi
  done
  echo "$1: $pkg is superseded, but no official recipe folder at or below $v exists" >&2
  return 1
}
skeleton_has() {
  local f sha
  for f in "${2:-$REPO_ROOT}"/tests/lines/*.env; do
    sha="$(sed -n 's/^SULU_SKELETON_SHA=//p' "$f")"
    if ! git -C "$WORK/clones/sulu-skeleton" cat-file -e "$sha^{commit}" 2>/dev/null; then
      echo "sulu-skeleton has no commit $sha; run skeleton_pins first" >&2
      return 0
    fi
    if git -C "$WORK/clones/sulu-skeleton" cat-file -e "$sha:$1" 2>/dev/null; then return 0; fi
  done
  return 1
}
official_files() {
  local path
  while IFS= read -r path; do
    case "$path" in
      manifest.json|post-install.txt) echo "$path" ;;
      *) if ! skeleton_has "$path" "$1"; then echo "$path"; fi ;;
    esac
  done < <(cd "$1/$2" && find . -type f | sed 's|^\./||' | sort)
}

SERVERS=""
CONTAINERS=""
cleanup() {
  for s in $SERVERS; do kill "${s%%:*}" 2>/dev/null || true; done
  for c in $CONTAINERS; do docker rm -fv "$c" >/dev/null 2>&1 || true; done
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
  local pid=$!
  SERVERS="$SERVERS $pid:$name"
  for _ in $(seq 1 60); do
    curl -s -m 10 -o /dev/null "http://127.0.0.1:$port/" && return 0
    kill -0 "$pid" 2>/dev/null || break
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
  echo "=== $name" >>"$WORK/checks.log"
  if "$@" >>"$WORK/checks.log" 2>&1; then echo "PASS $name"; else echo "FAIL $name"; FAILURES=$((FAILURES + 1)); fi
}

check_servers() {
  local s
  for s in $SERVERS; do
    kill -0 "${s%%:*}" 2>/dev/null && continue
    echo "FAIL ${s#*:} server exited during the run, see $WORK/${s#*:}.log"
    FAILURES=$((FAILURES + 1))
  done
}

finish() {
  check_servers
  echo "$FAILURES failure(s); details in $WORK/checks.log"
  [ "$FAILURES" -eq 0 ]
}

lock_repo() { [ "$(jq -r --arg p "$1" '.[$p].recipe.repo' symfony.lock)" = "$2" ]; }
lock_version() { [ "$(jq -r --arg p "$1" '.[$p].recipe.version' symfony.lock)" = "$2" ]; }
installed() { composer show "$1" >/dev/null 2>&1; }
lock_recipes() {
  jq -r 'to_entries[] | select(.value.recipe) | "\(.key) \(.value.recipe.version) \(.value.recipe.repo)"' symfony.lock \
    | sed "s|$OUR_REPO|<this repo>|" | sort
}
skeleton_with_fixes() {
  local path="$1" tmp p recipe pkg
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/$(dirname "$path")"
  skel_show "$path" >"$tmp/$path" 2>/dev/null || { rm -rf "$tmp"; return 1; }
  while IFS= read -r p; do
    recipe="$(cut -d/ -f1-3 <<<"${p#"$PATCH_ROOT"/}")"
    [ "${p#"$PATCH_ROOT/$recipe"/}" = "$path.fix.patch" ] || continue
    pkg="${recipe%/*}"
    [ "$(jq -r --arg p "$pkg" '"\(.[$p].recipe.repo // "")/\(.[$p].recipe.version // "")"' symfony.lock)" = "$OUR_REPO/${recipe##*/}" ] || continue
    (cd "$tmp" && git apply "$p") || { rm -rf "$tmp"; return 1; }
  done < <(find "$PATCH_ROOT" -path "*/$path.fix.patch" 2>/dev/null)
  cat "$tmp/$path"
  rm -rf "$tmp"
}
same_as_skeleton() { skeleton_with_fixes "$1" | cmp -s - "$1"; }

# --no-install: framework-bundle and console must get their recipes from this endpoint, so it is set before the first install.
new_symfony_project() {
  local constraint="$1" dir="$2" plugin
  rm -rf "$dir"
  composer create-project "symfony/skeleton:$constraint" "$dir" --no-install --no-interaction
  composer config --working-dir="$dir" extra.symfony.endpoint --json "[\"$ENDPOINT_URL\", \"flex://defaults\"]"
  composer config --working-dir="$dir" extra.symfony.allow-contrib true
  composer config --working-dir="$dir" secure-http false
  for plugin in $(skel_show composer.json | jq -r '.config["allow-plugins"] | to_entries[] | select(.value == true) | .key'); do
    composer config --working-dir="$dir" "allow-plugins.$plugin" true
  done
  composer install --working-dir="$dir" --no-interaction
}

# /admin/login answers 302 whether the password is right or not; the API call tells them apart.
admin_api_after_login() {
  local password="$1" expected="$2" jar="$WORK/admin-login.cookies"
  rm -f "$jar"
  curl -s -o /dev/null -c "$jar" -H 'Content-Type: application/json' \
    -d "{\"username\":\"admin\",\"password\":\"$password\"}" http://127.0.0.1:8001/admin/login
  [ "$(curl -s -o /dev/null -b "$jar" -w '%{http_code}' http://127.0.0.1:8001/admin/api/users)" = "$expected" ]
}

runtime_checks() {
  local db=sulu-recipes-mysql mysql="${SULU_MYSQL_VERSION:-8.4}" platform=()
  # mysql:5.7 has no arm64 image.
  [ "$mysql" != 5.7 ] || platform=(--platform linux/amd64)
  check "admin build present" test -f public/build/admin/manifest.json
  for console in adminconsole websiteconsole; do
    for env in dev prod test; do
      check "$console boots in $env" env APP_ENV="$env" "bin/$console" cache:clear
      check "$console container in $env" env APP_ENV="$env" "bin/$console" debug:container --env-vars
    done
  done
  CONTAINERS="$CONTAINERS $db"
  docker rm -fv "$db" >/dev/null 2>&1 || true
  docker run -d --name "$db" ${platform[@]+"${platform[@]}"} -e MYSQL_ROOT_PASSWORD=ChangeMe -p 3307:3306 "mysql:$mysql" >/dev/null
  # mysqladmin ping already answers the init-phase server, which has no TCP; wait for a TCP connection.
  for _ in $(seq 1 90); do docker exec "$db" mysql -h 127.0.0.1 -uroot -pChangeMe -e "SELECT 1" >/dev/null 2>&1 && break; sleep 1; done
  echo "DATABASE_URL=\"mysql://root:ChangeMe@127.0.0.1:3307/sulu_recipes?serverVersion=$mysql&charset=utf8mb4\"" > .env.local
  check "sulu:build dev" bin/adminconsole sulu:build dev --no-interaction
  serve web 8001 public config/router.php
  check "/admin answers 200 with the Sulu admin" sh -c 'curl -fsL http://127.0.0.1:8001/admin | grep -qi sulu'
  check "admin login grants the admin API" admin_api_after_login admin 200
  check "wrong admin password is denied" admin_api_after_login wrong 401
  check "homepage renders the content block" sh -c 'curl -fs http://127.0.0.1:8001/ | grep -q "<h1>"'
}
