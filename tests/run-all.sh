#!/usr/bin/env bash
# Runs every test-*.sh and the repo checks that do not need a base ref. Exit 1 if anything fails.
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
status=0
for t in "$dir"/test-*.sh; do
  echo "== $(basename "$t")"
  out=$(bash "$t" 2>&1)
  grep -E '^(FAIL|skip)|^passed=' <<<"$out"
  grep -q '^passed=[0-9]* failed=0$' <<<"$out" || { status=1; echo "$out" | tail -20; }
done
exit $status
