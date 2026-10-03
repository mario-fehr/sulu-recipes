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

entries="$(add_lines_entries "$ROOT")"
while IFS= read -r bad; do
  if [ -n "$bad" ]; then fail "$bad: Flex skips this add-lines block (no file or content, unknown position, after_target without target, or an unexpanded placeholder)"; fi
done < <(jq -r 'select(.file == "" or .content == null or (.position | IN("top", "bottom", "after_target") | not) or (.position == "after_target" and .target == "") or (.file | test("%"))) | "\(.recipe) add-lines[\(.index)]"' <<<"$entries")
valid='select(.file != "" and .content != null and (.position | IN("top", "bottom", "after_target")) and (.position != "after_target" or .target != "") and (.file | test("%") | not))'
add_lines_tmp="$(mktemp -d)"
for line_file in "$ROOT"/tests/lines/*.env; do
  line="$(basename "$line_file" .env)"
  sha="$(sed -n 's/^SULU_SKELETON_SHA=//p' "$line_file")"
  line_entries="$(jq -c --arg l "sulu/sulu/$line" "$valid | select((.recipe | startswith(\"sulu/sulu/\") | not) or .recipe == \$l)" <<<"$entries")"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    git -C "$WORK/clones/sulu-skeleton" cat-file -e "$sha:$file" 2>/dev/null || continue
    base=""
    while IFS= read -r recipe; do
      case "$recipe" in sulu/sulu/*) [ "$recipe" = "sulu/sulu/$line" ] || continue ;; esac
      if [ -f "$ROOT/$recipe/$file" ]; then base="$base$recipe"$'\n'; fi
    done < <(recipe_dirs "$ROOT")
    if [ "$(grep -c . <<<"$base")" != 1 ]; then fail "$line $file: add-lines target must come from exactly one recipe folder, found: ${base//$'\n'/ }"; continue; fi
    base="${base%$'\n'}"
    conflicts="$(jq -s -r --arg f "$file" '
      [.[] | select(.file == $f)]
      | group_by([.position, .target, .content])
      | map({position: .[0].position, target: .[0].target, content: .[0].content, recipes: (map(.recipe) | unique)})
      | . as $b
      | [range(0; length) as $i | range(0; length) as $j | select($i != $j) | $b[$i] as $x | $b[$j] as $y
         | select(($x.recipes - $y.recipes) == $x.recipes)
         | select(($i < $j and $x.position == $y.position and $x.target == $y.target)
             or ($i < $j and $x.content == $y.content)
             or ($y.target != "" and ($x.content | contains($y.target))))
         | "\($x.recipes | join(",")) / \($y.recipes | join(","))"]
      | unique | .[]' <<<"$line_entries")"
    if [ -n "$conflicts" ]; then fail "$line $file: add-lines blocks of different recipes depend on the install order: ${conflicts//$'\n'/; }"; continue; fi
    cp "$ROOT/$base/$file" "$add_lines_tmp/assembled"
    while IFS= read -r e; do
      content="$(jq -r .content <<<"$e"; echo x)"; content="${content%$'\n'x}"
      apply_add_line "$add_lines_tmp/assembled" "$(jq -r .position <<<"$e")" "$(jq -r .target <<<"$e")" "$content" >"$add_lines_tmp/next"
      mv "$add_lines_tmp/next" "$add_lines_tmp/assembled"
    done < <(jq -c --arg f "$file" 'select(.file == $f) | {position, target, content}' <<<"$line_entries" | awk '!seen[$0]++')
    mkdir -p "$add_lines_tmp/expected/$(dirname "$file")"
    git -C "$WORK/clones/sulu-skeleton" show "$sha:$file" >"$add_lines_tmp/expected/$file"
    if [ -f "$PATCH_ROOT/$base/$file.fix.patch" ] && ! (cd "$add_lines_tmp/expected" && git apply "$PATCH_ROOT/$base/$file.fix.patch"); then
      fail "$line $file: the fix patch of $base/$file does not apply"; continue
    fi
    cmp -s "$add_lines_tmp/assembled" "$add_lines_tmp/expected/$file" || fail "$line $file: $base/$file plus the add-lines blocks differs from sulu/skeleton plus its fix patch"
  done < <(jq -r .file <<<"$line_entries" | sort -u)
done
rm -rf "$add_lines_tmp"
finish
