#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
upstream sulu-skeleton sulu/skeleton "$SULU_SKELETON_SHA"
SULU_BARE_SYMFONY="${SULU_BARE_SYMFONY:-7.4}"
P="$WORK/project-bare"
BARE_LOCK="$REPO_ROOT/tests/lines/$SULU_LINE.bare-lock.txt"
: >"$WORK/checks.log"
require_free_port 8001

"$REPO_ROOT/tests/build-endpoint.sh"
serve endpoint "$ENDPOINT_PORT" "$OUTPUT"

new_symfony_project "$SULU_BARE_SYMFONY.*" "$P"
cd "$P"
echo "symfony/framework-bundle $(composer show symfony/framework-bundle --format=json | jq -r '.versions[0]')"

# The documented bare install, with sulu/sulu at the pinned sulu/skeleton version; no other package from sulu/skeleton's set.
check "composer require sulu/sulu" composer require "sulu/sulu:~$SULU_SKELETON_VERSION" cmsig/seal-loupe-adapter --no-interaction
check "composer require --dev cmsig/seal-memory-adapter" composer require --dev cmsig/seal-memory-adapter --no-interaction
check "admin build downloaded" update_build_guarded

installed() { composer show "$1" >/dev/null 2>&1; }
no_lock_entry() { ! jq -e --arg p "$1" 'has($p)' symfony.lock >/dev/null; }

for pkg in $SUPERSEDED symfony-cmf/routing-bundle; do
  installed "$pkg" || continue
  check "lock $pkg from this repo" lock_repo "$pkg" "$OUR_REPO"
done
for pkg in scheb/2fa-bundle symfony/web-profiler-bundle; do check "no lock entry $pkg" no_lock_entry "$pkg"; done
lock_recipes > "$WORK/bare-lock.actual"
check "recipes match $(basename "$BARE_LOCK")" diff "$BARE_LOCK" "$WORK/bare-lock.actual"
check "security.yaml has no two_factor" sh -c '! grep -q two_factor config/packages/security.yaml'
check "no config/routes/web_profiler_admin.yaml" test ! -e config/routes/web_profiler_admin.yaml
check ".gitignore ignores /public/uploads/" grep -qx '/public/uploads/' .gitignore

runtime_checks

# Packages from sulu/skeleton's set installed later get their Sulu config from their recipes.
check "late require symfony/web-profiler-bundle" composer require --dev symfony/web-profiler-bundle --no-interaction
case "$SULU_BARE_SYMFONY" in
  7.4) profiler_recipe=7.3 ;;
  8.1) profiler_recipe=8.1 ;;
  *) profiler_recipe=unknown ;;
esac
check "lock symfony/web-profiler-bundle from this repo" lock_repo symfony/web-profiler-bundle "$OUR_REPO"
check "lock symfony/web-profiler-bundle recipe $profiler_recipe" lock_version symfony/web-profiler-bundle "$profiler_recipe"
check "admin profiler routes under /admin" sh -c 'APP_ENV=dev bin/adminconsole debug:router _wdt | grep -q "/admin/_wdt/{token}"'
check "late require scheb 2fa packages" composer require scheb/2fa-bundle scheb/2fa-email scheb/2fa-trusted-device --no-interaction
check "lock scheb/2fa-bundle from this repo" lock_repo scheb/2fa-bundle "$OUR_REPO"
check "lock scheb/2fa-bundle recipe 6.10" lock_version scheb/2fa-bundle 6.10
check "security.yaml matches sulu/skeleton after scheb" same_as_skeleton config/packages/security.yaml
rerun_scheb_recipe() {
  composer recipes:install scheb/2fa-bundle --force --no-interaction || return 1
  same_as_skeleton config/packages/security.yaml
}
check "security.yaml matches sulu/skeleton after scheb recipe rerun" rerun_scheb_recipe
check "adminconsole boots in dev with 2FA" env APP_ENV=dev bin/adminconsole cache:clear

finish
