#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# The placeholder tokens are built from parts so a bulk replace in the repo does not touch this file.
AT="@@"
T=$(mktemp -d); cd "$T" || exit 1
# A local "release" repo built from this working tree, tagged v0.1.0.
git init -q -b main rel
cp -r "$ROOT/.claude-plugin" "$ROOT/plugins" rel/
grep -rIl "${AT}[A-Z_]*${AT}" rel | xargs -r sed -i -e "s/${AT}OWNER${AT}/o/g" -e "s/${AT}AUTHOR${AT}/Test Author/g"
( cd rel && git add -A && git commit -qm release && git tag v0.1.0 )
SHA=$(git -C rel rev-parse 'v0.1.0^{commit}')
mkscript() {  # mkscript <sha> <name>: copy setup.sh with REPO, TAG and SHA forced
  sed -e 's|^REPO=.*|REPO="o/intent2ship"|' -e 's|^TAG=.*|TAG="v0.1.0"|' -e "s|^SHA=.*|SHA=\"$1\"|" \
    "$ROOT/cloud/setup.sh" > "$T/setup-$2.sh"
}
run() {  # run <script> <home> [PATH]
  env HOME="$2" PATH="${3:-$PATH}" INTENT2SHIP_CLONE_URL="file://$T/rel" bash "$1"
}

mkscript "" unset
expect "unset SHA: refuses, exit 0"          0 "SHA is not set"          run "$T/setup-unset.sh" "$T/h1"
expect "unset SHA: installs nothing"         0 -  bash -c "[ ! -e '$T/h1/.intent2ship' ] && [ ! -e '$T/h1/.claude' ]"

mkscript "0000000000000000000000000000000000000000" wrong
expect "wrong SHA: refuses, exit 0"          0 "expected 0000"           run "$T/setup-wrong.sh" "$T/h2"
expect "wrong SHA: clone removed"            0 -  bash -c "[ ! -e '$T/h2/.intent2ship' ]"

mkscript "abc" short
expect "short SHA refused"                   0 "40 hex"                  run "$T/setup-short.sh" "$T/h3"

mkscript "$SHA" good
if PATH=/usr/bin:/bin command -v claude >/dev/null 2>&1; then
  echo "skip fallback tests: a claude binary is on /usr/bin:/bin"
else
  expect "no claude CLI: user-level copy"    0 "user-level copies"       run "$T/setup-good.sh" "$T/h4" "/usr/bin:/bin"
  expect "skill copied and renamed"          0 "name: intent2ship-github" cat "$T/h4/.claude/skills/intent2ship/SKILL.md"
  expect "agents copied"                     0 -  bash -c "[ -f '$T/h4/.claude/agents/builder.md' ] && [ -f '$T/h4/.claude/agents/runner.md' ] && [ -f '$T/h4/.claude/agents/reviewer.md' ]"
  expect "re-run is safe"                    0 "user-level copies"       run "$T/setup-good.sh" "$T/h4" "/usr/bin:/bin"
fi

if command -v claude >/dev/null 2>&1; then
  expect "with claude CLI: plugin install"   0 "installed v0.1.0 as a plugin" run "$T/setup-good.sh" "$T/h5"
  expect "plugin is listed"                  0 "intent2ship@intent2ship" env HOME="$T/h5" claude plugin list
else
  echo "skip plugin install test: claude CLI not found"
fi
finish
