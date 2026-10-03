#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "${1:-$REPO_ROOT}" && pwd -P)"
cd "$ROOT"
dirs=()
for v in $RECIPE_VENDORS; do [ -d "$v" ] && dirs+=("$v"); done
[ "${#dirs[@]}" -gt 0 ] || { echo "no recipe directories under $ROOT" >&2; exit 1; }
config_dirs=()
for d in "${dirs[@]}"; do
  for c in "$d"/*/*/config; do [ -d "$c" ] && config_dirs+=("$c"); done
done

message() {
  case "$1" in
    symlink) echo "Symlinks are not allowed" ;;
    yml) echo "*.yml files should be renamed to *.yaml" ;;
    gitkeep) echo ".gitkeep files should be renamed to .gitignore" ;;
    indent) echo "Indentation must be a multiple of 4 spaces" ;;
    newline) echo "Should end with a newline" ;;
    https) echo "Use https when referencing symfony.com" ;;
    manifest) echo "Recipes must define a manifest.json file" ;;
    json) echo "Invalid JSON" ;;
    parameters) echo '"parameters" should be defined via the "container" configurator instead' ;;
    underscore) echo "Underscore notation is required for file and directory names under config/" ;;
    tilde) echo '"~" should be replaced with "null"' ;;
    makefile) echo "Symfony commands should not be wrapped in a Makefile" ;;
  esac
}

# Ported from callable-qa.yml in symfony/recipes; one "<check>\t<path>\t<line>" per finding, <line> may be empty.
findings() {
  local p
  find "${dirs[@]}" -type l | sed 's/^/symlink\t/; s/$/\t/'
  find "${dirs[@]}" -name '*.yml' | sed 's/^/yml\t/; s/$/\t/'
  find "${dirs[@]}" -name .gitkeep | sed 's/^/gitkeep\t/; s/$/\t/'
  find "${dirs[@]}" -type f \( -name '*.yaml' -o -name '*.json' \) \
    -exec perl -lne 'print "indent\t$ARGV\t$." unless /^((    )*[^ \t]|$)/; close ARGV if eof' {} +
  find "${dirs[@]}" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.txt' -o -name '*.md' -o -name '*.markdown' -o -name '*.json' \
    -o -name '*.rst' -o -name '*.php' -o -name '*.js' -o -name '*.css' -o -name '*.twig' \) \
    | while IFS= read -r p; do [ -z "$(tail -c1 "$p")" ] || printf 'newline\t%s\t%s\n' "$p" "$(($(wc -l <"$p") + 1))"; done
  { grep -rHn 'http://.*symfony\.com' "${dirs[@]}" || true; } | cut -d: -f1-2 | sed 's/^/https\t/; s/:\([0-9]*\)$/\t\1/'
  find "${dirs[@]}" -mindepth 2 -maxdepth 2 -type d '!' -exec test -f '{}/manifest.json' ';' -print | sed 's/^/manifest\t/; s/$/\t/'
  find "${dirs[@]}" -type f -name '*.json' | while IFS= read -r p; do jq -se 'length == 1' "$p" >/dev/null 2>&1 || printf 'json\t%s\t\n' "$p"; done
  if [ "${#config_dirs[@]}" -gt 0 ]; then
    { find "${config_dirs[@]}" -path '*/config/packages/*' -type f \( -name '*.yaml' -o -name '*.yml' \) -exec grep -Hn '^parameters:' {} + || true; } \
      | cut -d: -f1-2 | sed 's/^/parameters\t/; s/:\([0-9]*\)$/\t\1/'
    find "${config_dirs[@]}" -type f | perl -ne 'chomp; print "underscore\t$_\t\n" unless m{^[^/]+/[^/]+/[^/]+/config/[0-9a-z_./]+$}'
  fi
  { find "${dirs[@]}" -type f \( -name '*.yaml' -o -name '*.yml' \) -exec grep -FHn ': ~' {} + || true; } \
    | cut -d: -f1-2 | sed 's/^/tilde\t/; s/:\([0-9]*\)$/\t\1/'
  { find "${dirs[@]}" -type f -name Makefile -exec grep -EHn 'bin/console|\$\(CONSOLE\)' {} + || true; } \
    | cut -d: -f1-2 | sed 's/^/makefile\t/; s/:\([0-9]*\)$/\t\1/'
}

failures=0
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# The exceptions belong to the checked tree. A symlink is never excepted: the preview endpoint relies on that.
exceptions=()
# Read through a symlink, the list would print any file the runner can read.
if [ -L "$ROOT/tests" ] || [ -L "$ROOT/tests/style-exceptions.txt" ]; then
  fail "tests/style-exceptions.txt must not be or sit behind a symlink"
elif [ -f "$ROOT/tests/style-exceptions.txt" ]; then
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    case "$e" in *"  #reason: "?*) ;; *) fail "exception without a reason: $e"; continue ;; esac
    e="${e%%  #reason: *}"
    case "$e" in symlink\ *) fail "exception not allowed: $e"; continue ;; esac
    exceptions+=("$e")
  done <"$ROOT/tests/style-exceptions.txt"
fi
# Not a process substitution: a failing check must stop the script, not shorten the list.
findings >"$WORK/style-findings.tsv"
used="|"
while IFS=$'\t' read -r check path line; do
  excepted=0
  for e in ${exceptions[@]+"${exceptions[@]}"}; do [ "$e" = "$check $path" ] && excepted=1; done
  if [ "$excepted" = 1 ]; then used="$used$check $path|"; continue; fi
  fail "$check $path${line:+:$line}: $(message "$check")"
  [ "${GITHUB_ACTIONS:-}" != true ] || echo "::error file=$path${line:+,line=$line}::$(message "$check")"
done <"$WORK/style-findings.tsv"
for e in ${exceptions[@]+"${exceptions[@]}"}; do
  case "$used" in *"|$e|"*) ;; *) fail "stale exception: $e" ;; esac
done
echo "$failures failure(s)"
[ "$failures" -eq 0 ]
