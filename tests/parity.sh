#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
SKELETON_DIR="${SKELETON_DIR:-$HOME/Projects/private/sulu-flex-skeleton}"
A="$WORK/flex"; B="$WORK/upstream"
REPORT="$WORK/parity-report.txt"
DIFFS="$WORK/parity-diffs"
mkdir -p "$DIFFS"
find "$DIFFS" -name '*.diff' -delete
EXPECTED="$REPO_ROOT/tests/parity-expected.txt"

"$REPO_ROOT/tests/build-endpoint.sh"
start_endpoint

# A scratch COMPOSER_HOME allows the plain-http local endpoint without touching either compared composer.json.
export COMPOSER_CACHE_DIR="${COMPOSER_CACHE_DIR:-$(composer config --global cache-dir)}"
export COMPOSER_HOME="$WORK/composer-home"
mkdir -p "$COMPOSER_HOME"
echo '{"config":{"secure-http":false}}' > "$COMPOSER_HOME/config.json"

if [ "${SULU_RECIPES_REUSE:-0}" = 1 ] && [ -d "$A/vendor" ] && [ -d "$B/vendor" ]; then
  echo "SULU_RECIPES_REUSE=1: reusing $A and $B"
else
  rm -rf "$A" "$B"
  composer create-project mario-fehr/sulu-flex-skeleton:dev-main "$A" --no-interaction \
    --repository="{\"type\":\"path\",\"url\":\"$SKELETON_DIR\",\"options\":{\"symlink\":false}}"
  composer create-project "sulu/skeleton:$SULU_SKELETON_VERSION" "$B" --no-interaction
  (cd "$A" && update_build_guarded)
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

{
  { diff -rq "$A" "$B" -x .git -x vendor -x var -x composer.lock 2>&1 || true; } | sed -e "s|$A|<flex>|g" -e "s|$B|<upstream>|g"
  for f in .env .env.dev .env.test .env.stage .gitignore; do
    [ -f "$A/$f" ] && [ -f "$B/$f" ] || continue
    diff <(blocks "$A/$f") <(blocks "$B/$f") | grep '^[<>]' | sed "s|^|$f |" || true
  done
  diff <(grep -oE '[A-Za-z\\]+::class => \[[^]]*\]' "$A/config/bundles.php" | sort) \
       <(grep -oE '[A-Za-z\\]+::class => \[[^]]*\]' "$B/config/bundles.php" | sort) | grep '^[<>]' | sed 's|^|bundles.php |' || true
  for console in adminconsole websiteconsole; do
    for env in dev prod stage; do
      for ext in framework doctrine flysystem fos_rest jms_serializer monolog stof_doctrine_extensions; do
        diff <(cd "$A" && APP_ENV=$env bin/$console debug:config "$ext" 2>/dev/null | norm) \
             <(cd "$B" && APP_ENV=$env bin/$console debug:config "$ext" 2>/dev/null | norm) >"$DIFFS/$console-$env-$ext.diff" \
          || echo "debug:config $console $env $ext differs"
      done
      diff <(cd "$A" && APP_ENV=$env bin/$console debug:router 2>/dev/null | norm) \
           <(cd "$B" && APP_ENV=$env bin/$console debug:router 2>/dev/null | norm) >"$DIFFS/$console-$env-router.diff" \
        || echo "debug:router $console $env differs"
    done
  done
} | sort > "$REPORT"

if diff <(sed 's/  #reason: .*$//' "$EXPECTED" | grep -v '^$' | sort) "$REPORT"; then
  echo "PASS parity: only documented differences"
else
  echo "FAIL parity: '<' expected but missing, '>' unexplained (full report: $REPORT)"
  exit 1
fi
