#!/usr/bin/env bash
# Usage: check-version-bump.sh <base ref>
# Fails when files under plugins/ changed since the base ref but the plugin version did not.
# Users only receive an update when the version changes, so a change without a bump never ships.
# Claude, Cursor, and Codex manifests must move to the same version together.
set -u
base=${1:?usage: check-version-bump.sh <base ref>}
claude=plugins/intent2ship/.claude-plugin/plugin.json
cursor=plugins/intent2ship/.cursor-plugin/plugin.json
codex=plugins/intent2ship/.codex-plugin/plugin.json
version() { python3 -c 'import json,sys; print(json.load(sys.stdin).get("version",""))'; }

changed=$(git diff --name-only "$base"...HEAD -- plugins/)
[[ -n "$changed" ]] || { echo "no plugin files changed"; exit 0; }

for file in "$claude" "$cursor" "$codex"; do
  if [[ ! -f $file ]]; then
    echo "Plugin files changed but $file is missing." >&2
    exit 1
  fi
done

claude_new=$(version < "$claude")
cursor_new=$(version < "$cursor")
codex_new=$(version < "$codex")
same=0
[[ "$claude_new" == "$cursor_new" && "$claude_new" == "$codex_new" ]] && same=1
if [[ $same -eq 0 ]]; then
  echo "Plugin manifest versions differ: claude $claude_new, cursor $cursor_new, codex $codex_new. Bump them together." >&2
  exit 1
fi

old=$(git show "$base:$claude" 2>/dev/null | version 2>/dev/null || true)
if [[ "$old" == "$claude_new" ]]; then
  echo "Plugin files changed but the version is still $claude_new. Bump it in $claude." >&2
  while read -r f; do echo "  changed: $f" >&2; done <<<"$changed"
  exit 1
fi
echo "version bumped: ${old:-none} -> $claude_new"
