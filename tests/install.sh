#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
upstream sulu-skeleton sulu/skeleton "$SULU_SKELETON_SHA"
P="$WORK/project-a"
: >"$WORK/checks.log"
require_free_port "$ENDPOINT_PORT"
require_free_port 8001

"$REPO_ROOT/tests/build-endpoint.sh"
serve endpoint "$ENDPOINT_PORT" "$OUTPUT"

new_symfony_project '7.4.*' "$P"
cd "$P"
# Same package set as sulu/skeleton: Sulu's config assumes it (2FA in security.yaml, web profiler routes).
pkgs() { skel_show composer.json | jq -r --arg k "$1" '.[$k] | to_entries[] | select(.key | test("^(php|ext-.*)$") | not) | "\(.key):\(.value)"'; }
require=(); require_dev=()
while IFS= read -r p; do require+=("$p"); done < <(pkgs require)
while IFS= read -r p; do require_dev+=("$p"); done < <(pkgs require-dev)
[ "${#require[@]}" -eq 0 ] || composer require "${require[@]}" --no-update --no-interaction
[ "${#require_dev[@]}" -eq 0 ] || composer require --dev "${require_dev[@]}" --no-update --no-interaction
composer update --no-interaction
# sulu/skeleton commits public/build/admin; recipes cannot ship it sensibly, Sulu downloads the matching build instead.
update_build_guarded

for pkg in $SUPERSEDED symfony-cmf/routing-bundle; do check "lock $pkg from this repo" lock_repo "$pkg" "$OUR_REPO"; done
check "lock symfony/mailer official" lock_repo symfony/mailer github.com/symfony/recipes
check "lock doctrine/doctrine-bundle recipe 2.13" lock_version doctrine/doctrine-bundle 2.13

for f in src/Kernel.php public/index.php config/preload.php config/services.yaml \
         config/packages/framework.yaml config/packages/security.yaml bin/console \
         templates/base.html.twig config/routes/scheb_2fa.yaml config/routes/fos_js_routing.yaml \
         config/routes/web_profiler_admin.yaml \
         config/packages/doctrine.yaml config/webspaces/website.xml bin/adminconsole config/packages/sulu_admin.yaml .env.stage; do
  check "file $f matches sulu/skeleton" same_as_skeleton "$f"
done

check "admin route 2fa_login_check_admin" bin/adminconsole debug:router 2fa_login_check_admin
check "no website route fos_js_routing_js" sh -c 'bin/websiteconsole debug:router >/dev/null && ! bin/websiteconsole debug:router fos_js_routing_js'

runtime_checks

echo "Manual: open http://127.0.0.1:8001/admin and log in with the user sulu:build created (admin / admin)."
finish
