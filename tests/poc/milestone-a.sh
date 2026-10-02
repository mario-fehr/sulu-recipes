#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
P="$WORK/project-a"
DB_CONTAINER=sulu-poc-mysql
: >"$WORK/checks.log"

"$REPO_ROOT/tests/poc/build-endpoint.sh"
start_endpoint

rm -rf "$P"
composer create-project 'symfony/skeleton:7.4.*' "$P" --no-install --no-interaction
cd "$P"
composer config extra.symfony.endpoint --json "[\"$ENDPOINT_URL\", \"flex://defaults\"]"
composer config extra.symfony.allow-contrib true
composer config secure-http false
for plugin in $(skel_show composer.json | jq -r '.config["allow-plugins"] | to_entries[] | select(.value == true) | .key'); do
  composer config "allow-plugins.$plugin" true
done
composer install --no-interaction
# Same package set as sulu/skeleton: Sulu's config assumes it (2FA in security.yaml, web profiler routes).
pkgs() { skel_show composer.json | jq -r --arg k "$1" '.[$k] | to_entries[] | select(.key | test("^(php|ext-.*)$") | not) | "\(.key):\(.value)"'; }
OLD_IFS="$IFS"; IFS=$'\n'; set -f
composer require $(pkgs require) --no-update --no-interaction
composer require --dev $(pkgs require-dev) --no-update --no-interaction
IFS="$OLD_IFS"; set +f
composer update --no-interaction
# sulu/skeleton commits public/build/admin; recipes cannot ship it sensibly, Sulu downloads the matching build instead.
update_build_guarded

lock_repo() { [ "$(jq -r --arg p "$1" '.[$p].recipe.repo' symfony.lock)" = "$2" ]; }
same_as_skeleton() { skel_show "$1" | cmp -s - "$1"; }

for pkg in $SUPERSEDED symfony-cmf/routing-bundle; do check "lock $pkg from this repo" lock_repo "$pkg" "$OUR_REPO"; done
check "lock symfony/mailer official" lock_repo symfony/mailer github.com/symfony/recipes

for f in src/Kernel.php public/index.php config/preload.php config/services.yaml \
         config/packages/framework.yaml config/packages/security.yaml bin/console \
         templates/base.html.twig config/routes/scheb_2fa.yaml config/routes/fos_js_routing.yaml \
         config/packages/doctrine.yaml config/webspaces/website.xml bin/adminconsole config/packages/sulu_admin.yaml .env.stage; do
  check "file $f matches sulu/skeleton" same_as_skeleton "$f"
done

check "admin build present" test -f public/build/admin/manifest.json

for console in adminconsole websiteconsole; do
  for env in dev prod test; do
    check "$console boots in $env" env APP_ENV="$env" "bin/$console" cache:clear
    check "$console container in $env" env APP_ENV="$env" "bin/$console" debug:container --env-vars
  done
done
check "admin route 2fa_login_check_admin" bin/adminconsole debug:router 2fa_login_check_admin
check "no website route fos_js_routing_js" sh -c 'bin/websiteconsole debug:router >/dev/null && ! bin/websiteconsole debug:router fos_js_routing_js'

docker rm -f "$DB_CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$DB_CONTAINER" -e MYSQL_ROOT_PASSWORD=ChangeMe -p 3307:3306 mysql:8.4 >/dev/null
# mysqladmin ping already answers the init-phase server, which has no TCP; wait for a TCP connection.
for _ in $(seq 1 90); do docker exec "$DB_CONTAINER" mysql -h 127.0.0.1 -uroot -pChangeMe -e "SELECT 1" >/dev/null 2>&1 && break; sleep 1; done
echo 'DATABASE_URL="mysql://root:ChangeMe@127.0.0.1:3307/su_poc?serverVersion=8.4&charset=utf8mb4"' > .env.local
check "sulu:build dev" bin/adminconsole sulu:build dev --no-interaction

php -S 127.0.0.1:8001 -t public config/router.php >"$WORK/web.log" 2>&1 &
WEB_PID=$!
trap 'kill "$ENDPOINT_PID" "$WEB_PID" 2>/dev/null || true; docker rm -f "$DB_CONTAINER" >/dev/null 2>&1 || true' EXIT
sleep 2
check "/admin answers 200 with the Sulu admin" sh -c 'curl -fsL http://127.0.0.1:8001/admin | grep -qi sulu'
check "homepage renders the content block" sh -c 'curl -fs http://127.0.0.1:8001/ | grep -q "<h1>"'

echo "Manual: open http://127.0.0.1:8001/admin and log in with the user sulu:build created (admin / admin)."
finish
