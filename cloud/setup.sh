#!/bin/bash
# Setup script for a Claude Code cloud environment: paste it into the "Setup script" field.
# It installs one pinned release of intent2ship and refuses anything else.
# To move to a new release, change TAG and SHA together. SHA is the output of:
#   git ls-remote https://github.com/adityaagarkar912/intent2ship.git 'refs/tags/<tag>^{}'
REPO="adityaagarkar912/intent2ship"
TAG="v0.1.0"
SHA="@@RELEASE_SHA@@"
URL="${INTENT2SHIP_CLONE_URL:-https://github.com/$REPO.git}"
DIR="$HOME/.intent2ship"

# A failed install must not block the session, so every failure exits 0 with a message.
fail() { echo "intent2ship setup: $*" >&2; exit 0; }

case "$SHA" in
  *[!0-9a-f]* | "") fail "SHA is not set; edit this script" ;;
esac
[ "${#SHA}" -eq 40 ] || fail "SHA must be 40 hex characters"
command -v git >/dev/null 2>&1 || fail "git not found"

rm -rf "$DIR"
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$TAG" "$URL" "$DIR" || fail "could not clone $URL at $TAG"
got=$(git -C "$DIR" rev-parse HEAD)
if [ "$got" != "$SHA" ]; then
  rm -rf "$DIR"
  fail "tag $TAG points to $got, expected $SHA; refusing to install"
fi

if command -v claude >/dev/null 2>&1 \
  && claude plugin marketplace add "$DIR" >/dev/null 2>&1 \
  && claude plugin install intent2ship@intent2ship >/dev/null 2>&1; then
  echo "intent2ship: installed $TAG as a plugin"
  exit 0
fi

# Without the claude CLI: copy the skill and agents to the user level.
# The agents then have no plugin prefix: builder, runner, reviewer.
mkdir -p "$HOME/.claude/skills" "$HOME/.claude/agents" || fail "cannot create the ~/.claude folders"
rm -rf "$HOME/.claude/skills/intent2ship"
cp -r "$DIR/plugins/intent2ship/skills/github" "$HOME/.claude/skills/intent2ship" || fail "could not copy the skill"
# -i.bak is accepted by both GNU and BSD sed. The backup is removed.
sed -i.bak 's/^name: github$/name: intent2ship-github/' "$HOME/.claude/skills/intent2ship/SKILL.md" \
  && rm -f "$HOME/.claude/skills/intent2ship/SKILL.md.bak"
cp "$DIR"/plugins/intent2ship/agents/*.md "$HOME/.claude/agents/" || fail "could not copy the agents"
echo "intent2ship: installed $TAG as user-level copies (plugin install unavailable)"
exit 0
