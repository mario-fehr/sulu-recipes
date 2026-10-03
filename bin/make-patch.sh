#!/usr/bin/env bash
# Writes the fix or adapt patch of an edited recipe file into tests/patches/.
# Usage: bin/make-patch.sh fix|adapt <recipe-file> [--reason <text> --evidence <text>] [--lines "<line> ..."]
source "$(dirname "$0")/../tests/lib.sh"
usage() { echo "usage: bin/make-patch.sh fix|adapt <recipe-file> [--reason <text> --evidence <text>] [--lines \"<line> ...\"]" >&2; exit 1; }
kind="${1:-}"; file="${2:-}"; reason=""; evidence=""; lines=""; lines_set=""
case "$kind" in fix) letter=e; other=adapt ;; adapt) letter=f; other=fix ;; *) usage ;; esac
[ -n "$file" ] || usage
shift 2
while [ $# -gt 0 ]; do
  case "$1" in
    --reason) reason="${2:-}"; shift 2 ;;
    --evidence) evidence="${2:-}"; shift 2 ;;
    --lines) lines="${2:-}"; lines_set=1; shift 2 ;;
    *) usage ;;
  esac
done
file="${file#"$REPO_ROOT"/}"
recipe="$(cut -d/ -f1-3 <<<"$file")"
path="${file#"$recipe"/}"
case "$recipe" in sulu/sulu/*) [ "$recipe" = "sulu/sulu/$SULU_LINE" ] || { echo "$recipe is not the recipe of SULU_LINE=$SULU_LINE" >&2; exit 1; } ;; esac
if [ ! -f "$REPO_ROOT/$recipe/manifest.json" ] || [ ! -f "$REPO_ROOT/$file" ]; then echo "$file is not a recipe file" >&2; exit 1; fi
case "$path" in assets/admin/*) echo "assets/admin/ must stay identical to sulu/skeleton for sulu:admin:update-build" >&2; exit 1 ;; esac
grep -qI '' "$REPO_ROOT/$file" || { echo "$file is binary; binary patches are not supported" >&2; exit 1; }
upstream sulu-skeleton sulu/skeleton "$SULU_SKELETON_SHA"
official_clones
skeleton_pins
if skeleton_has "$path"; then
  skel_show "$path" >/dev/null 2>&1 || { echo "sulu/skeleton has $path only for another line; run with that SULU_LINE" >&2; exit 1; }
  base_show() { skel_show "$path"; }
else
  origin="$(official_origin "$recipe")" || exit 1
  read -r o_clone o_sha o_folder <<<"$origin"
  if [ -z "$origin" ] || ! git -C "$WORK/clones/$o_clone" cat-file -e "$o_sha:$o_folder/$path" 2>/dev/null; then
    echo "no upstream file for $path: neither sulu/skeleton nor an official recipe has it" >&2; exit 1
  fi
  base_show() { git -C "$WORK/clones/$o_clone" show "$o_sha:$o_folder/$path"; }
fi

out="$PATCH_ROOT/$recipe/$path.$kind.patch"
for l in $lines; do [ -f "$REPO_ROOT/tests/lines/$l.env" ] || { echo "--lines names $l, which has no tests/lines/$l.env" >&2; exit 1; }; done
scope="$lines"
if [ -z "$lines_set" ] && [ -f "$out" ]; then scope="$(sed -n '/^--- a\//q; s/^Lines: //p' "$out")"; fi
if [ -n "$scope" ] && [[ " $scope " != *" $SULU_LINE "* ]]; then echo "the patch applies to lines $scope; run with one of them as SULU_LINE" >&2; exit 1; fi
other_patch="$PATCH_ROOT/$recipe/$path.$other.patch"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"; cleanup' EXIT
mkdir -p "$tmp/base/$(dirname "$path")" "$tmp/target/$(dirname "$path")"
base_show >"$tmp/base/$path"
cp "$REPO_ROOT/$file" "$tmp/target/$path"
if [ "$kind" = fix ] && [ -f "$other_patch" ] && patch_in_line "$other_patch" "$SULU_LINE"; then
  (cd "$tmp/target" && git apply -R "$other_patch") || { echo "the adapt patch does not reverse-apply to $file; update it first" >&2; exit 1; }
fi
if [ "$kind" = adapt ] && [ -f "$other_patch" ] && patch_in_line "$other_patch" "$SULU_LINE"; then
  (cd "$tmp/base" && git apply "$other_patch") || { echo "the fix patch does not apply to the upstream $path" >&2; exit 1; }
fi

rc=0
diff -u --label "a/$path" --label "b/$path" "$tmp/base/$path" "$tmp/target/$path" >"$tmp/diff" || rc=$?
case "$rc" in
  0) if [ -f "$out" ]; then rm "$out"; echo "no difference; removed $out"; else echo "no difference; nothing written"; fi; exit 0 ;;
  1) ;;
  *) echo "diff failed" >&2; exit 1 ;;
esac

if [ -f "$out" ]; then
  header="$(sed '/^--- a\//,$d' "$out")"
  if [ -n "$lines_set" ]; then header="$(sed '/^Lines: /d' <<<"$header")"; fi
  if [ -n "$lines" ]; then header="$header"$'\n'"Lines: $lines"; fi
elif [ -n "$reason" ] && [ -n "$evidence" ]; then
  header="$(printf 'Reason: (%s) %s\nEvidence: %s\n' "$letter" "$reason" "$evidence")"
  if [ -n "$lines" ]; then header="$header"$'\n'"Lines: $lines"; fi
else
  echo "a new patch needs --reason and --evidence" >&2; exit 1
fi
mkdir -p "$(dirname "$out")"
{ printf '%s\n\n' "$header"; cat "$tmp/diff"; } >"$out"
echo "wrote $out"
