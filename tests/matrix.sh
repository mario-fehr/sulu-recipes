#!/usr/bin/env bash
# Prints the lines, install, install_push and bare matrices of qa.yml from tests/lines/*.env.
set -euo pipefail
cd "$(dirname "$0")/lines"

if [ -n "${1:-}" ]; then
  [ -f "$1.env" ] || { echo "no pin file tests/lines/$1.env for line $1" >&2; exit 1; }
  lines=$(jq -cn --arg l "$1" '[$l]')
else
  lines=$(find . -maxdepth 1 -name '*.env' | sort | jq -R -s -c 'split("\n") | map(select(. != "") | sub("^.*/"; "") | rtrimstr(".env"))')
fi

install="" install_push="" bare=""
for l in $(jq -r '.[]' <<<"$lines"); do
  unset SULU_PHP_MYSQL SULU_BARE_RUNS
  # shellcheck source=/dev/null
  . "./$l.env"
  [ -n "${SULU_PHP_MYSQL:-}" ] || { echo "no SULU_PHP_MYSQL in tests/lines/$l.env" >&2; exit 1; }
  for pm in $SULU_PHP_MYSQL; do
    case "$pm" in [0-9]*:[0-9]*) ;; *) echo "bad PHP:MySQL pair '$pm' in tests/lines/$l.env" >&2; exit 1 ;; esac
    pair=$(jq -cn --arg line "$l" --arg php "${pm%%:*}" --arg mysql "${pm#*:}" '{line: $line, php: $php, mysql: $mysql}')
    install+=$pair
  done
  # On push only the last pair, so an upstream regression on an old PHP or MySQL cannot block publishing.
  install_push+=$pair
  for run in ${SULU_BARE_RUNS:-}; do
    IFS=: read -r php symfony deps lock <<<"$run"
    if [ -z "$php" ] || [ -z "$symfony" ]; then echo "bad bare run '$run' in tests/lines/$l.env" >&2; exit 1; fi
    case "$deps" in highest|lowest) ;; *) echo "bad bare run '$run' in tests/lines/$l.env: deps must be highest or lowest" >&2; exit 1 ;; esac
    mysql=""
    for pm in $SULU_PHP_MYSQL; do [ "${pm%%:*}" != "$php" ] || mysql="${pm#*:}"; done
    [ -n "$mysql" ] || { echo "no MySQL version for PHP $php in tests/lines/$l.env" >&2; exit 1; }
    bare+=$(jq -cn --arg line "$l" --arg php "$php" --arg mysql "$mysql" --arg symfony "$symfony" --arg deps "$deps" --arg lock "$lock" \
      '{line: $line, php: $php, mysql: $mysql, symfony: $symfony, deps: $deps, lock: $lock}')
  done
done

echo "lines=$lines"
echo "install=$(jq -s -c . <<<"$install")"
echo "install_push=$(jq -s -c . <<<"$install_push")"
echo "bare=$(jq -s -c . <<<"$bare")"
