#!/usr/bin/env bash
# Checks that every script has a header and that docs/scripts.md and CONTRIBUTING.md name every script, variable and CI job.
# Usage: tests/docs.sh [<dir>]
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "${1:-$REPO_ROOT}" && pwd -P)"
failures=0
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

cd "$ROOT"
for f in tests/*.sh bin/*.sh; do
  header="$(awk 'NR > 1 && !/^#/ { exit } NR > 1' "$f")"
  if [ -z "$header" ]; then
    fail "$f has no header comment after the shebang"
  else
    if [ "$f" != tests/lib.sh ] && ! grep -q '^# Usage: ' <<<"$header"; then
      fail "$f has no '# Usage:' line in its header"
    fi
    grep -qvE '^# (Usage|Env): |^# shellcheck ' <<<"$header" || fail "$f has no purpose line in its header"
  fi
  grep -qF "$f" docs/scripts.md || fail "$f is not in docs/scripts.md"
done

while read -r name; do
  grep -qw "$name" docs/scripts.md || fail "$name is not in docs/scripts.md"
done < <(grep -rhoE --include='*.sh' --include='*.env' --include='*.yml' 'SULU_[A-Z0-9_]+|SKELETON_DIR' tests bin .github/workflows | sort -u)

jobs="$(awk '/^        name: / { sub(/^        name: /, ""); sub(/ \(.*/, ""); print }' .github/workflows/qa.yml)"
[ -n "$jobs" ] || fail "no job names found in .github/workflows/qa.yml"
while read -r job; do
  [ -n "$job" ] || continue
  grep -qE "\`$job( |\`)" CONTRIBUTING.md || fail "qa.yml job $job is not in CONTRIBUTING.md"
done <<<"$jobs"

if [ "$failures" -gt 0 ]; then exit 1; fi
echo "docs complete"
