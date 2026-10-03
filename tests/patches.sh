#!/usr/bin/env bash
# Checks that every recipe file equals sulu/skeleton at the pin of every line, or its official recipe at the pin, plus its patches.
# Usage: tests/patches.sh [<dir>]
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "${1:-$REPO_ROOT}" && pwd -P)"
PATCH_ROOT="$ROOT/tests/patches"
upstream sulu-skeleton sulu/skeleton

fail() { echo "FAIL $1"; FAILURES=$((FAILURES + 1)); }

if [ -d "$PATCH_ROOT" ]; then
  while IFS= read -r p; do
    rel="${p#"$PATCH_ROOT"/}"
    recipe="$(cut -d/ -f1-3 <<<"$rel")"
    rest="${rel#"$recipe"/}"
    case "$rest" in
      *.fix.patch) letter=e; path="${rest%.fix.patch}" ;;
      *.adapt.patch) letter=f; path="${rest%.adapt.patch}" ;;
      *) fail "$rel: the name must end in .fix.patch or .adapt.patch"; continue ;;
    esac
    if [ ! -f "$ROOT/$recipe/manifest.json" ] || [ ! -f "$ROOT/$recipe/$path" ]; then fail "$rel: no recipe file $recipe/$path"; fi
    case "$path" in assets/admin/*) fail "$rel: assets/admin/ must stay identical to sulu/skeleton for sulu:admin:update-build" ;; esac
    grep -q "^Reason: ($letter) ." "$p" || fail "$rel: no 'Reason: ($letter) ...' line"
    grep -q '^Evidence: .' "$p" || fail "$rel: no 'Evidence: ...' line"
  done < <(find "$PATCH_ROOT" -type f | sort)
fi

for line_file in "$ROOT"/tests/lines/*.env; do
  line="$(basename "$line_file" .env)"
  sha="$(sed -n 's/^SULU_SKELETON_SHA=//p' "$line_file")"
  [ -n "$sha" ] || { fail "$line: no SULU_SKELETON_SHA"; continue; }
  upstream sulu-skeleton sulu/skeleton "$sha"
  while IFS= read -r recipe; do
    case "$recipe" in sulu/sulu/*) [ "$recipe" = "sulu/sulu/$line" ] || continue ;; esac
    while IFS= read -r path; do
      if ! git -C "$WORK/clones/sulu-skeleton" cat-file -e "$sha:$path" 2>/dev/null; then
        if [ -f "$PATCH_ROOT/$recipe/$path.fix.patch" ] || [ -f "$PATCH_ROOT/$recipe/$path.adapt.patch" ]; then
          fail "$line $recipe/$path: patched, but sulu/skeleton has no $path"
        fi
        continue
      fi
      if ! err="$(rebuild_file "$recipe" "$path" "$sha" 2>&1 >"$WORK/rebuilt")"; then
        fail "$line $recipe/$path: $err"
      elif ! cmp -s "$WORK/rebuilt" "$ROOT/$recipe/$path"; then
        fail "$line $recipe/$path: differs from sulu/skeleton plus its patches"
      fi
    done < <(recipe_files "$ROOT" "$recipe")
  done < <(recipe_dirs "$ROOT")
done

official_clones
while IFS= read -r recipe; do
  origin="$(official_origin "$recipe")" || { fail "$recipe: no official origin"; continue; }
  [ -n "$origin" ] || continue
  read -r clone sha folder <<<"$origin"
  while IFS= read -r path; do
    rc=0; err="$(rebuild_file "$recipe" "$path" "$sha" "$clone" "$folder/$path" 2>&1 >"$WORK/rebuilt")" || rc=$?
    if [ "$rc" = 1 ]; then
      if [ -f "$PATCH_ROOT/$recipe/$path.fix.patch" ] || [ -f "$PATCH_ROOT/$recipe/$path.adapt.patch" ]; then
        fail "$recipe/$path: patched, but the official recipe has no $path"
      fi
    elif [ "$rc" != 0 ]; then
      fail "$recipe/$path: $err"
    elif ! cmp -s "$WORK/rebuilt" "$ROOT/$recipe/$path"; then
      fail "$recipe/$path: differs from the official recipe plus its patches"
    fi
  done < <(official_files "$ROOT" "$recipe")
done < <(recipe_dirs "$ROOT")
finish
