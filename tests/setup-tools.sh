#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

if [ ! -d "$TOOLS/recipes-checker/.git" ]; then
  git clone https://github.com/symfony-tools/recipes-checker.git "$TOOLS/recipes-checker"
fi
# Same unpinned branch as symfony/recipes' callable-flex-update.yml, which builds flex/main.
git -C "$TOOLS/recipes-checker" fetch -q origin main
git -C "$TOOLS/recipes-checker" checkout -q -f FETCH_HEAD
composer install --no-interaction --working-dir="$TOOLS/recipes-checker"
# The locked Symfony 5.4.1 http-client crashes on PHP 8.5; later 5.4 patches fix it.
composer update --no-interaction --working-dir="$TOOLS/recipes-checker" 'symfony/*' -W
