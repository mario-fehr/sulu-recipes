#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require_repo_name
SRC="$(cd "${1:-$REPO_ROOT}" && pwd -P)"
FLEX_BRANCH="${2:-flex/main}"
CHECKER="php $TOOLS/recipes-checker/run"
BUILD="$WORK/build"

rm -rf "$BUILD" "$OUTPUT"
mkdir -p "$BUILD" "$OUTPUT"

vendors=()
for v in $RECIPE_VENDORS; do
  [ -d "$SRC/$v" ] && vendors+=("$v")
done
[ "${#vendors[@]}" -gt 0 ] || { echo "no recipe sources found" >&2; exit 1; }

export GIT_INDEX_FILE="$WORK/build.index"
rm -f "$GIT_INDEX_FILE"
git -C "$SRC" add -A -- "${vendors[@]}"
TREE="$(git -C "$SRC" write-tree)"
unset GIT_INDEX_FILE
echo "$TREE" > "$WORK/endpoint.tree.current"
git -C "$SRC" archive "$TREE" -- "${vendors[@]}" | tar -x -C "$BUILD"

cd "$BUILD"
$CHECKER lint:manifests
# sulu/skeleton ships an intentionally empty sulu_article.yaml; lint:yaml rejects empty root keys.
find . -type f \( -name '*.yaml' -o -name '*.yml' \) | sed 's|^\./||' | grep -vx 'sulu/sulu/[^/]*/config/packages/sulu_article.yaml' | $CHECKER lint:yaml
$CHECKER lint:packages
recipe_dirs=(*/*/*)
git -C "$SRC" ls-tree "$TREE" "${recipe_dirs[@]}" |$CHECKER generate:flex-endpoint "$SULU_RECIPES_REPO" main "$FLEX_BRANCH" "$OUTPUT"
echo "endpoint compiled into $OUTPUT"
