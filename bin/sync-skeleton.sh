#!/usr/bin/env bash
source "$(dirname "$0")/../tests/lib.sh"
upstream sulu-skeleton sulu/skeleton "$SULU_SKELETON_SHA"
failed=0
dirs="$(if [ $# -gt 0 ]; then printf '%s\n' "$@"; else recipe_dirs "$REPO_ROOT"; fi)"
while IFS= read -r recipe; do
  recipe="${recipe#"$REPO_ROOT"/}"; recipe="${recipe%/}"
  case "$recipe" in sulu/sulu/*) [ "$recipe" = "sulu/sulu/$SULU_LINE" ] || continue ;; esac
  while IFS= read -r path; do
    if ! git -C "$WORK/clones/sulu-skeleton" cat-file -e "$SULU_SKELETON_SHA:$path" 2>/dev/null; then
      if [ -f "$PATCH_ROOT/$recipe/$path.fix.patch" ] || [ -f "$PATCH_ROOT/$recipe/$path.adapt.patch" ]; then
        echo "kept $recipe/$path (removed upstream)" >&2
        failed=1
      fi
      continue
    fi
    if ! rebuild_file "$recipe" "$path" "$SULU_SKELETON_SHA" >"$WORK/rebuilt"; then
      echo "kept $recipe/$path" >&2
      failed=1
    elif ! cmp -s "$WORK/rebuilt" "$REPO_ROOT/$recipe/$path"; then
      cp "$WORK/rebuilt" "$REPO_ROOT/$recipe/$path"
      echo "updated $recipe/$path"
    fi
  done < <(recipe_files "$REPO_ROOT" "$recipe")
done <<<"$dirs"
exit "$failed"
