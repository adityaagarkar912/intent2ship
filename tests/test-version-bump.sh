#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
T=$(cd "$(mktemp -d)" && pwd -P); cd "$T" || exit 1
git init -q -b main r; cd r || exit 1
mkdir -p plugins/intent2ship docs
write_versions() {
  local v=$1
  mkdir -p plugins/intent2ship/.claude-plugin \
           plugins/intent2ship/.cursor-plugin \
           plugins/intent2ship/.codex-plugin
  echo "{\"name\":\"intent2ship\",\"version\":\"$v\"}" > plugins/intent2ship/.claude-plugin/plugin.json
  echo "{\"name\":\"intent2ship\",\"version\":\"$v\"}" > plugins/intent2ship/.cursor-plugin/plugin.json
  echo "{\"name\":\"intent2ship\",\"version\":\"$v\"}" > plugins/intent2ship/.codex-plugin/plugin.json
}
write_versions 0.1.0
echo a > plugins/intent2ship/file; echo d > docs/x; git add -A; git commit -qm base
check() { bash "$ROOT/tests/check-version-bump.sh" "$@"; }

git checkout -q -b docs-only; echo d2 >> docs/x; git commit -qam docs
expect "no plugin change passes"            0 "no plugin files changed" check main

git checkout -q main; git checkout -q -b change-no-bump; echo b >> plugins/intent2ship/file; git commit -qam change
expect "plugin change without bump fails"   1 "version is still 0.1.0"  check main

write_versions 0.1.1; git commit -qam bump
expect "plugin change with bump passes"     0 "0.1.0 -> 0.1.1"          check main

git checkout -q main; git checkout -q -b claude-only
echo c >> plugins/intent2ship/file
echo '{"name":"intent2ship","version":"0.1.1"}' > plugins/intent2ship/.claude-plugin/plugin.json
git commit -qam claude-only
expect "claude-only bump fails"             1 "versions differ"         check main

git checkout -q main; git checkout -q -b new-plugin; git rm -q -r plugins
write_versions 0.2.0; git add -A; git commit -qm rewrite
expect "bump to any new version passes"     0 "0.1.0 -> 0.2.0"          check main
finish
