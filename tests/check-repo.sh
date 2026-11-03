#!/usr/bin/env bash
# Fails when a placeholder is left in the repo or something that looks like a secret is committed.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
fail=0
ex=(--exclude-dir=.git --exclude-dir=node_modules --exclude=check-repo.sh)

# @@RELEASE_SHA@@ is allowed: it can only be filled after the release tag exists, and
# cloud/setup.sh refuses to install while it is unset.
ph=$(grep -rIn "${ex[@]}" -E '@@[A-Z_]+@@' . | grep -v '@@RELEASE_SHA@@' || true)
if [[ -n "$ph" ]]; then echo "Placeholders left in the repo:"; echo "$ph"; fail=1; fi

pat='(ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|sk-ant-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'
sec=$(grep -rIn "${ex[@]}" -E "$pat" . || true)
if [[ -n "$sec" ]]; then echo "Possible secrets:"; echo "$sec" | cut -c1-120; fail=1; fi

exit $fail
