#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
CHECKER="php $TOOLS/recipes-checker/run"
BUILD="$WORK/build"

rm -rf "$BUILD" "$OUTPUT"
mkdir -p "$BUILD" "$OUTPUT"

vendors=""
for v in $RECIPE_VENDORS; do
  [ -d "$REPO_ROOT/$v" ] && { cp -R "$REPO_ROOT/$v" "$BUILD/"; vendors="$vendors $v"; }
done
[ -n "$vendors" ] || { echo "no recipe sources found" >&2; exit 1; }

export GIT_INDEX_FILE="$WORK/build.index"
rm -f "$GIT_INDEX_FILE"
git -C "$REPO_ROOT" add -A -- $vendors
TREE="$(git -C "$REPO_ROOT" write-tree)"
unset GIT_INDEX_FILE

cd "$BUILD"
$CHECKER lint:manifests
# sulu/skeleton ships an intentionally empty sulu_article.yaml; lint:yaml rejects empty root keys.
find . -type f \( -name '*.yaml' -o -name '*.yml' \) | sed 's|^\./||' | grep -vx 'sulu/sulu/3.0/config/packages/sulu_article.yaml' | $CHECKER lint:yaml
$CHECKER lint:packages
git -C "$REPO_ROOT" ls-tree "$TREE" $(ls -d */*/*) | $CHECKER generate:flex-endpoint mario-fehr/sulu-recipes main flex/main "$OUTPUT"
echo "endpoint compiled into $OUTPUT"
