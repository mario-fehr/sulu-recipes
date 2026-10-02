#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

if [ ! -d "$TOOLS/recipes-checker/.git" ]; then
  git clone https://github.com/symfony-tools/recipes-checker.git "$TOOLS/recipes-checker"
fi
git -C "$TOOLS/recipes-checker" checkout -q "$RECIPES_CHECKER_SHA"
composer install --no-interaction --working-dir="$TOOLS/recipes-checker"
# The locked Symfony 5.4.1 http-client crashes on PHP 8.5; later 5.4 patches fix it.
composer update --no-interaction --working-dir="$TOOLS/recipes-checker" 'symfony/*' -W
