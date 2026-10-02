#!/usr/bin/env bash
source "$(dirname "$0")/../tests/lib.sh"
repo="$1"; official="$2"; target="$REPO_ROOT/$3"
case "$repo" in
  recipes) name=symfony-recipes; gh_repo=symfony/recipes; sha="$SYMFONY_RECIPES_SHA" ;;
  contrib) name=symfony-recipes-contrib; gh_repo=symfony/recipes-contrib; sha="$SYMFONY_RECIPES_CONTRIB_SHA" ;;
  *) echo "repo must be recipes or contrib" >&2; exit 1 ;;
esac
upstream "$name" "$gh_repo" "$sha"
upstream sulu-skeleton sulu/skeleton "$SULU_SKELETON_SHA"
src="$WORK/clones/$name"

rm -rf "$target"
mkdir -p "$target"
git -C "$src" archive "$sha" "$official" | tar -x -C "$WORK"
cp -R "$WORK/$official/." "$target/"

(cd "$target" && find . -type f ! -name manifest.json ! -name post-install.txt | sed 's|^\./||') | while read -r f; do
  if skel_show "$f" >/dev/null 2>&1; then
    skel_show "$f" > "$target/$f"
    echo "sulu: $f"
  else
    echo "official: $f"
  fi
done
