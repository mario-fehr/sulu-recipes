#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
SKELETON_DIR="${SKELETON_DIR:-$HOME/Projects/private/sulu-flex-skeleton}"
A="$WORK/flex"; B="$WORK/upstream"
SRC="$WORK/skeleton-src"
REPORT="$WORK/parity-report.txt"
DIFFS="$WORK/parity-diffs"
mkdir -p "$DIFFS"
find "$DIFFS" -name '*.diff' -delete
EXPECTED="$REPO_ROOT/tests/lines/$SULU_LINE.parity-expected.txt"
: >"$WORK/checks.log"
require_free_port "$ENDPOINT_PORT"

"$REPO_ROOT/tests/build-endpoint.sh"
serve endpoint "$ENDPOINT_PORT" "$OUTPUT"

# A scratch COMPOSER_HOME allows the plain-http local endpoint without touching either compared composer.json.
export COMPOSER_CACHE_DIR="${COMPOSER_CACHE_DIR:-$(composer config --global cache-dir)}"
export COMPOSER_HOME="$WORK/composer-home"
mkdir -p "$COMPOSER_HOME"
echo '{"config":{"secure-http":false}}' > "$COMPOSER_HOME/config.json"

if [ "${SULU_RECIPES_REUSE:-0}" = 1 ] && [ -d "$A/vendor" ] && [ -d "$B/vendor" ]; then
  if ! cmp -s "$WORK/endpoint.tree" "$WORK/endpoint.tree.current"; then
    echo "recipes changed since install; rerun without SULU_RECIPES_REUSE" >&2
    exit 1
  fi
  if [ "$(cat "$WORK/parity.line" 2>/dev/null)" != "$SULU_LINE" ]; then
    echo "projects were installed for another line; rerun without SULU_RECIPES_REUSE" >&2
    exit 1
  fi
  echo "SULU_RECIPES_REUSE=1: reusing $A and $B"
else
  if [ -e "$SKELETON_DIR/composer.lock" ] || [ -e "$SKELETON_DIR/symfony.lock" ]; then
    echo "$SKELETON_DIR has been installed into; use a clean checkout" >&2
    exit 1
  fi
  rm -rf "$A" "$B" "$SRC" "$WORK/endpoint.tree" "$WORK/parity.line"
  mkdir -p "$SRC"
  # Flex keeps the skeleton's own endpoints after SYMFONY_ENDPOINT, so a recipe removed here would still come from flex/main.
  (cd "$SKELETON_DIR" && tar -cf - --exclude=.git --exclude=vendor .) | tar -xf - -C "$SRC"
  composer config --working-dir="$SRC" extra.symfony.endpoint --json "[\"$ENDPOINT_URL\", \"flex://defaults\"]"
  composer create-project 'mario-fehr/sulu-flex-skeleton:*@dev' "$A" --no-interaction \
    --repository="{\"type\":\"path\",\"url\":\"$SRC\",\"options\":{\"symlink\":false}}"
  composer create-project "sulu/skeleton:$SULU_SKELETON_VERSION" "$B" --no-interaction
  (cd "$A" && update_build_guarded)
  cp "$WORK/endpoint.tree.current" "$WORK/endpoint.tree"
  echo "$SULU_LINE" > "$WORK/parity.line"
fi

va="$(cd "$A" && composer show sulu/sulu --format=json | jq -r '.versions[0]')"
vb="$(cd "$B" && composer show sulu/sulu --format=json | jq -r '.versions[0]')"
[ "$va" = "$vb" ] || { echo "sulu/sulu differs: $va vs $vb" >&2; exit 1; }

norm() { sed -e "s|$A|<project>|g" -e "s|$B|<project>|g" -e "s|APP_SECRET=[0-9a-f][0-9a-f]*|APP_SECRET=<secret>|g"; }
blocks() {
  awk '/^###> /{n=$2; buf=""; inb=1; next}
       /^###< /{print n "\t" buf; inb=0; next}
       inb { if ($0 != "") buf = buf $0 "|"; next }
       NF { print "_outside\t" $0 }' "$1" | norm | sort
}
compare() {
  local label="$1" out="$2" failed=0
  shift 2
  (cd "$A" && "$@") >"$WORK/side-flex.out" 2>>"$WORK/checks.log" || { echo "$label failed on flex"; failed=1; }
  (cd "$B" && "$@") >"$WORK/side-upstream.out" 2>>"$WORK/checks.log" || { echo "$label failed on upstream"; failed=1; }
  [ "$failed" = 0 ] || return 0
  diff <(norm <"$WORK/side-flex.out") <(norm <"$WORK/side-upstream.out") >"$out" || echo "$label differs"
}

{
  { diff -rq "$A" "$B" -x .git -x vendor -x var -x composer.lock 2>&1 || true; } | sed -e "s|$A|<flex>|g" -e "s|$B|<upstream>|g"
  for f in .env .env.dev .env.test .env.stage .gitignore; do
    { [ -f "$A/$f" ] && [ -f "$B/$f" ]; } || continue
    diff <(blocks "$A/$f") <(blocks "$B/$f") | grep '^[<>]' | sed "s|^|$f |" || true
  done
  diff <(grep -oE '[A-Za-z\\]+::class => \[[^]]*\]' "$A/config/bundles.php" | sort) \
       <(grep -oE '[A-Za-z\\]+::class => \[[^]]*\]' "$B/config/bundles.php" | sort) | grep '^[<>]' | sed 's|^|bundles.php |' || true
  for console in adminconsole websiteconsole; do
    for env in dev prod stage; do
      for ext in framework doctrine flysystem fos_rest jms_serializer monolog stof_doctrine_extensions; do
        compare "debug:config $console $env $ext" "$DIFFS/$console-$env-$ext.diff" env APP_ENV="$env" "bin/$console" debug:config "$ext"
      done
      compare "debug:router $console $env" "$DIFFS/$console-$env-router.diff" env APP_ENV="$env" "bin/$console" debug:router
    done
  done
} | sort > "$REPORT"
check_servers
[ "$FAILURES" -eq 0 ] || exit 1

if diff <(sed 's/  #reason: .*$//' "$EXPECTED" | grep -v '^$' | sort) "$REPORT"; then
  echo "PASS parity: only documented differences"
else
  echo "FAIL parity: '<' expected but missing, '>' unexplained (full report: $REPORT)"
  exit 1
fi
