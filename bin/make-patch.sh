#!/usr/bin/env bash
# Writes the fix or adapt patch of an edited recipe file into tests/patches/.
# Usage: bin/make-patch.sh fix|adapt <recipe-file> [--reason <text> --evidence <text>]
source "$(dirname "$0")/../tests/lib.sh"
usage() { echo "usage: bin/make-patch.sh fix|adapt <recipe-file> [--reason <text> --evidence <text>]" >&2; exit 1; }
kind="${1:-}"; file="${2:-}"; reason=""; evidence=""
case "$kind" in fix) letter=e; other=adapt ;; adapt) letter=f; other=fix ;; *) usage ;; esac
[ -n "$file" ] || usage
shift 2
while [ $# -gt 0 ]; do
  case "$1" in
    --reason) reason="${2:-}"; shift 2 ;;
    --evidence) evidence="${2:-}"; shift 2 ;;
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
skel_show "$path" >/dev/null 2>&1 || { echo "sulu/skeleton has no $path at the pin" >&2; exit 1; }

out="$PATCH_ROOT/$recipe/$path.$kind.patch"
other_patch="$PATCH_ROOT/$recipe/$path.$other.patch"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"; cleanup' EXIT
mkdir -p "$tmp/base/$(dirname "$path")" "$tmp/target/$(dirname "$path")"
skel_show "$path" >"$tmp/base/$path"
cp "$REPO_ROOT/$file" "$tmp/target/$path"
if [ "$kind" = fix ] && [ -f "$other_patch" ]; then
  (cd "$tmp/target" && git apply -R "$other_patch") || { echo "the adapt patch does not reverse-apply to $file; update it first" >&2; exit 1; }
fi
if [ "$kind" = adapt ] && [ -f "$other_patch" ]; then
  (cd "$tmp/base" && git apply "$other_patch") || { echo "the fix patch does not apply to sulu/skeleton's $path" >&2; exit 1; }
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
elif [ -n "$reason" ] && [ -n "$evidence" ]; then
  header="$(printf 'Reason: (%s) %s\nEvidence: %s\n' "$letter" "$reason" "$evidence")"
else
  echo "a new patch needs --reason and --evidence" >&2; exit 1
fi
mkdir -p "$(dirname "$out")"
{ printf '%s\n\n' "$header"; cat "$tmp/diff"; } >"$out"
echo "wrote $out"
