#!/usr/bin/env bash
# Installs sulu/sulu alone into a fresh symfony/skeleton from the local endpoint and runs the checks.
# Usage: tests/install-bare.sh
# Env: SULU_BARE_SYMFONY SULU_BARE_DEPS SULU_BARE_LOCK
source "$(dirname "$0")/lib.sh"
upstream sulu-skeleton sulu/skeleton "$SULU_SKELETON_SHA"
SULU_BARE_SYMFONY="${SULU_BARE_SYMFONY:-7.4}"
P="$WORK/project-bare"
BARE_LOCK="$REPO_ROOT/tests/lines/$SULU_LINE.bare-lock${SULU_BARE_LOCK:+.$SULU_BARE_LOCK}.txt"
case "${SULU_BARE_DEPS:-highest}" in
  highest) deps=() ;;
  # SULU_BARE_LOWEST_FLOOR: lowest versions sulu/sulu's constraints allow that do not boot on this Symfony, raised for the lowest run only.
  lowest) read -ra deps <<<"${SULU_BARE_LOWEST_FLOOR:-}"; deps+=(--prefer-lowest) ;;
  *) echo "SULU_BARE_DEPS must be highest or lowest" >&2; exit 1 ;;
esac
: >"$WORK/checks.log"
require_free_port "$ENDPOINT_PORT"
require_free_port 8001

"$REPO_ROOT/tests/build-endpoint.sh"
serve endpoint "$ENDPOINT_PORT" "$OUTPUT"

case "$SULU_BARE_SYMFONY" in
  *-dev) skeleton_constraint="${SULU_BARE_SYMFONY%-dev}.x-dev" ;;
  *) skeleton_constraint="$SULU_BARE_SYMFONY.*" ;;
esac
new_symfony_project "$skeleton_constraint" "$P"
cd "$P"
echo "symfony/framework-bundle $(composer show symfony/framework-bundle --format=json | jq -r '.versions[0]')"

# The documented bare install, with sulu/sulu at the pinned sulu/skeleton version; no other package from sulu/skeleton's set.
read -ra bare_require <<<"${SULU_BARE_REQUIRE:-}"
read -ra bare_require_dev <<<"${SULU_BARE_REQUIRE_DEV:-}"
check "composer require sulu/sulu" composer require "sulu/sulu:~$SULU_SKELETON_VERSION" ${bare_require[@]+"${bare_require[@]}"} ${deps[@]+"${deps[@]}"} --no-interaction
if [ "${#bare_require_dev[@]}" -gt 0 ]; then
  check "composer require --dev ${bare_require_dev[*]}" composer require --dev "${bare_require_dev[@]}" --no-interaction
fi
check "admin build downloaded" update_build_guarded

no_lock_entry() { ! jq -e --arg p "$1" 'has($p)' symfony.lock >/dev/null; }

for pkg in $SUPERSEDED $OWN_RECIPES; do
  installed "$pkg" || continue
  check "lock $pkg from this repo" lock_repo "$pkg" "$OUR_REPO"
done
for pkg in scheb/2fa-bundle scheb/2fa-email scheb/2fa-trusted-device symfony/web-profiler-bundle; do check "no lock entry $pkg" no_lock_entry "$pkg"; done
lock_recipes > "$WORK/bare-lock.actual"
check "recipes match $(basename "$BARE_LOCK")" diff "$BARE_LOCK" "$WORK/bare-lock.actual"
check "security.yaml has no two_factor" sh -c '! grep -q two_factor config/packages/security.yaml'
check "no config/routes/web_profiler_admin.yaml" test ! -e config/routes/web_profiler_admin.yaml
check "no .env.test" test ! -e .env.test
for f in AGENTS.md CLAUDE.md; do check "no $f" test ! -e "$f"; done
if [ "$(jq -r '."symfony/framework-bundle".recipe.version' symfony.lock)" = 6.4 ]; then
  check "no .symfony.local.yaml" test ! -e .symfony.local.yaml
else
  check ".symfony.local.yaml exists" test -f .symfony.local.yaml
fi
for f in $TOOLING_FILES; do check "no $f" test ! -e "$f"; done
for d in tests/phpstan tests/rector; do check "no $d/" test ! -e "$d"; done
check ".gitignore ignores /public/uploads/" grep -qx '/public/uploads/' .gitignore

runtime_checks

check "late require --dev phpunit/phpunit" composer require --dev phpunit/phpunit --no-interaction
check "lock phpunit/phpunit from this repo" lock_repo phpunit/phpunit "$OUR_REPO"
check "lock phpunit/phpunit recipe 11.1" lock_version phpunit/phpunit 11.1
check ".env.test matches sulu/skeleton" same_as_skeleton .env.test
if installed cmsig/seal-memory-adapter; then
  remove_memory_adapter() {
    composer remove --dev cmsig/seal-memory-adapter --no-interaction || return 1
    ! grep -q SEAL_DSN .env.test
  }
  check "remove cmsig/seal-memory-adapter drops SEAL_DSN from .env.test" remove_memory_adapter
fi

# Packages from sulu/skeleton's set installed later get their Sulu config from their recipes.
check "late require symfony/web-profiler-bundle" composer require --dev symfony/web-profiler-bundle --no-interaction
case "$SULU_BARE_SYMFONY" in
  7.4) profiler_recipe=7.3 ;;
  8.1|8.2|8.2-dev) profiler_recipe=8.1 ;;
  *) profiler_recipe=unknown ;;
esac
check "lock symfony/web-profiler-bundle from this repo" lock_repo symfony/web-profiler-bundle "$OUR_REPO"
check "lock symfony/web-profiler-bundle recipe $profiler_recipe" lock_version symfony/web-profiler-bundle "$profiler_recipe"
check "admin profiler routes under /admin" sh -c 'APP_ENV=dev bin/adminconsole debug:router _wdt | grep -q "/admin/_wdt/{token}"'
check "late require scheb/2fa-bundle alone" composer require scheb/2fa-bundle --no-interaction
for console in adminconsole websiteconsole; do
  for env in dev prod test; do
    check "$console boots in $env with scheb/2fa-bundle alone" env APP_ENV="$env" "bin/$console" cache:clear
  done
done
check "late require scheb 2fa email and trusted device" composer require scheb/2fa-email scheb/2fa-trusted-device --no-interaction
for pkg in scheb/2fa-email scheb/2fa-trusted-device; do
  check "lock $pkg from this repo" lock_repo "$pkg" "$OUR_REPO"
  check "lock $pkg recipe 6.10" lock_version "$pkg" 6.10
done
for f in config/packages/scheb_2fa_email.yaml config/packages/scheb_2fa_trusted_device.yaml; do check "$f exists" test -f "$f"; done
check "lock scheb/2fa-bundle from this repo" lock_repo scheb/2fa-bundle "$OUR_REPO"
check "lock scheb/2fa-bundle recipe 6.10" lock_version scheb/2fa-bundle 6.10
check "security.yaml matches sulu/skeleton after scheb" same_as_skeleton config/packages/security.yaml
rerun_scheb_recipe() {
  composer recipes:install scheb/2fa-bundle --force --no-interaction || return 1
  test -f config/packages/scheb_2fa_email.yaml || return 1
  test -f config/packages/scheb_2fa_trusted_device.yaml || return 1
  same_as_skeleton config/packages/security.yaml
}
check "scheb recipe rerun keeps 2FA files and security.yaml" rerun_scheb_recipe
check "adminconsole boots in dev with 2FA" env APP_ENV=dev bin/adminconsole cache:clear
remove_scheb_email() {
  composer remove scheb/2fa-email --no-interaction || return 1
  test ! -e config/packages/scheb_2fa_email.yaml || return 1
  APP_ENV=dev bin/adminconsole cache:clear
}
check "remove scheb/2fa-email drops its file and boots" remove_scheb_email

finish
