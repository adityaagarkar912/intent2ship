#!/usr/bin/env bash
# shellcheck disable=SC2034
# Shared helpers for the newer test files. Source this file; do not run it.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
PASS=0; FAIL=0
# expect <label> <expected exit code> <grep pattern, or - for none> <command...>
expect() {
  local label=$1 want=$2 pat=$3; shift 3
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [[ $rc -eq $want ]] && { [[ $pat == - ]] || grep -q -- "$pat" <<<"$out"; }; then
    PASS=$((PASS + 1)); echo "ok   $label"
  else
    FAIL=$((FAIL + 1)); echo "FAIL $label (rc=$rc, wanted $want, pattern '$pat')"
    echo "$out" | tail -5 | sed 's/^/       /'
  fi
}
finish() { echo; echo "passed=$PASS failed=$FAIL"; [[ $FAIL -eq 0 ]]; }
