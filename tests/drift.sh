#!/usr/bin/env bash
# Writes one file per place where sulu/skeleton or an official recipe moved past its pin into $WORK/drift/.
# Usage: tests/drift.sh
source "$(dirname "$0")/lib.sh"
UP="$WORK/clones"
SKEL="$UP/sulu-skeleton"
OUT="$WORK/drift"
rm -rf "$OUT"
mkdir -p "$OUT"

upstream sulu-skeleton sulu/skeleton
upstream symfony-recipes symfony/recipes
upstream symfony-recipes-contrib symfony/recipes-contrib

newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$2" ]; }

list() {
  [ -n "$1" ] || { echo "- none"; return; }
  while read -r path; do echo "- \`$path\`"; done <<<"$1"
}

shipped="$(for v in $RECIPE_VENDORS; do
  for d in "$REPO_ROOT/$v"/*/*/; do
    if [ -d "$d" ]; then (cd "$d" && find . -type f ! -name manifest.json ! -name post-install.txt | sed 's|^\./||'); fi
  done
done | sort -u)"

lines="$(cd "$REPO_ROOT/tests/lines" && for f in *.env; do echo "${f%.env}"; done | sort -V)"

for line in $lines; do
  pin_sha="$(sed -n 's/^SULU_SKELETON_SHA=//p' "$REPO_ROOT/tests/lines/$line.env")"
  pin_version="$(sed -n 's/^SULU_SKELETON_VERSION=//p' "$REPO_ROOT/tests/lines/$line.env")"
  upstream sulu-skeleton sulu/skeleton "$pin_sha"
  latest="$(git -C "$SKEL" tag -l "$line.*" | grep -E "^${line//./\\.}\.[0-9]+$" | sort -V | tail -n 1 || true)"
  [ -n "$latest" ] || continue
  newer "$pin_version" "$latest" || continue
  changed="$(git -C "$SKEL" diff --name-only --no-renames "$pin_sha" "$latest")"
  ours="$(grep -Fx -f <(echo "$shipped") <<<"$changed" || true)"
  others="$(grep -Fxv -f <(echo "$shipped") <<<"$changed" || true)"
  patched=""
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    for recipe in $(recipe_dirs "$REPO_ROOT"); do
      case "$recipe" in sulu/sulu/*) [ "$recipe" = "sulu/sulu/$line" ] || continue ;; esac
      [ -f "$PATCH_ROOT/$recipe/$path.fix.patch" ] || [ -f "$PATCH_ROOT/$recipe/$path.adapt.patch" ] || continue
      rc=0; rebuild_file "$recipe" "$path" "$latest" >/dev/null 2>&1 || rc=$?
      case "$rc" in
        0) status="applies" ;;
        1) status="removed upstream" ;;
        2) status="does not apply (fix)" ;;
        *) status="does not apply (adapt)" ;;
      esac
      patched="$patched- \`$recipe/$path\`: $status"$'\n'
    done
  done <<<"$ours"
  {
    echo "sulu/skeleton $line: $latest released"
    echo
    echo "\`tests/lines/$line.env\` pins \`$pin_version\` (\`${pin_sha:0:7}\`). Compare: https://github.com/sulu/skeleton/compare/$pin_sha...$latest"
    echo
    echo "Changed files the recipes ship:"
    echo
    list "$ours"
    echo
    echo "Patches against $latest:"
    echo
    if [ -n "$patched" ]; then printf '%s' "$patched"; else echo "- none"; fi
    echo
    echo "Other changed files:"
    echo
    list "$others"
  } > "$OUT/skeleton-$line.md"
done

highest="$(tail -n 1 <<<"$lines")"
for minor in $(git -C "$SKEL" tag -l | grep -E '^[0-9]+\.[0-9]+\.0$' | sed 's/\.0$//' | sort -V); do
  [ -f "$REPO_ROOT/tests/lines/$minor.env" ] && continue
  newer "$highest" "$minor" || continue
  {
    echo "sulu/skeleton: new line $minor"
    echo
    echo "\`sulu/skeleton\` tagged \`$minor.0\`: https://github.com/sulu/skeleton/tree/$minor.0"
    echo
    echo "There is no \`tests/lines/$minor.env\` yet. Supporting the line needs that pin file, a \`tests/lines/$minor.parity-expected.txt\`, a \`sulu/sulu/$minor/\` recipe taken from the tag, and a \`$minor\` branch of \`sulu-flex-skeleton\`."
  } > "$OUT/skeleton-line-$minor.md"
done

upstream symfony-recipes symfony/recipes "$SYMFONY_RECIPES_SHA"
upstream symfony-recipes-contrib symfony/recipes-contrib "$SYMFONY_RECIPES_CONTRIB_SHA"
for pkg in $SUPERSEDED $SULU_YAML_PACKAGES; do
  if git -C "$UP/symfony-recipes" cat-file -e "$SYMFONY_RECIPES_SHA:$pkg" 2>/dev/null; then
    repo=symfony-recipes; gh_repo=symfony/recipes; pin="$SYMFONY_RECIPES_SHA"; pin_var=SYMFONY_RECIPES_SHA
  elif git -C "$UP/symfony-recipes-contrib" cat-file -e "$SYMFONY_RECIPES_CONTRIB_SHA:$pkg" 2>/dev/null; then
    repo=symfony-recipes-contrib; gh_repo=symfony/recipes-contrib; pin="$SYMFONY_RECIPES_CONTRIB_SHA"; pin_var=SYMFONY_RECIPES_CONTRIB_SHA
  else
    echo "$pkg is in neither official recipe repository at its pin" >&2
    exit 1
  fi
  commits="$(git -C "$UP/$repo" log --format='%h %s' "$pin..origin/main" -- "$pkg/")"
  [ -n "$commits" ] || continue
  case " $SUPERSEDED " in
    *" $pkg "*) role="A recipe in this repository supersedes it." ;;
    *) role="Flex installs it from the official endpoint, and \`config/packages/sulu.yaml\` of the \`sulu/sulu\` recipe holds Sulu's differences to it." ;;
  esac
  {
    echo "Official recipe changed: $pkg"
    echo
    echo "\`$pkg/\` in \`$gh_repo\` changed since \`${pin:0:7}\` (\`$pin_var\` in \`tests/pins.env\`). $role"
    echo
    echo "Commits:"
    echo
    # Bare #N would link to this repository's issues, and @user would ping on every body edit.
    while read -r sha subject; do
      echo "- [\`$sha\`](https://github.com/$gh_repo/commit/$sha) $subject"
    done < <(sed -E -e "s,(^|[^[:alnum:]_/])#([0-9]+),\1$gh_repo#\2,g" -e "s,(^|[[:space:](])@([[:alnum:]][[:alnum:]-]*),\1\`@\2\`,g" <<<"$commits")
    echo
    echo "Changed paths:"
    echo
    list "$(git -C "$UP/$repo" diff --name-only --no-renames "$pin" origin/main -- "$pkg/")"
  } > "$OUT/official-${pkg//\//-}.md"
done

found=0
for f in "$OUT"/*.md; do
  [ -e "$f" ] || continue
  head -n 1 "$f"
  found=1
done
[ "$found" = 1 ] || echo "no drift"
