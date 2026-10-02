#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
CHECKER="php $TOOLS/recipes-checker/run"
BUILD="$WORK/build"

rm -rf "$BUILD" "$OUTPUT"
mkdir -p "$BUILD" "$OUTPUT"

vendors=()
for v in $RECIPE_VENDORS; do
  [ -d "$REPO_ROOT/$v" ] && vendors+=("$v")
done
[ "${#vendors[@]}" -gt 0 ] || { echo "no recipe sources found" >&2; exit 1; }

export GIT_INDEX_FILE="$WORK/build.index"
rm -f "$GIT_INDEX_FILE"
git -C "$REPO_ROOT" add -A -- "${vendors[@]}"
TREE="$(git -C "$REPO_ROOT" write-tree)"
unset GIT_INDEX_FILE
echo "$TREE" > "$WORK/endpoint.tree.current"
git -C "$REPO_ROOT" archive "$TREE" -- "${vendors[@]}" | tar -x -C "$BUILD"

cd "$BUILD"
$CHECKER lint:manifests
# sulu/skeleton ships an intentionally empty sulu_article.yaml; lint:yaml rejects empty root keys.
find . -type f \( -name '*.yaml' -o -name '*.yml' \) | sed 's|^\./||' | grep -vx 'sulu/sulu/[^/]*/config/packages/sulu_article.yaml' | $CHECKER lint:yaml
$CHECKER lint:packages
recipe_dirs=(*/*/*)
git -C "$REPO_ROOT" ls-tree "$TREE" "${recipe_dirs[@]}" |$CHECKER generate:flex-endpoint mario-fehr/sulu-recipes main flex/main "$OUTPUT"
echo "endpoint compiled into $OUTPUT"
