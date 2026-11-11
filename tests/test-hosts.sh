#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

check_hosts() {
  python3 - "$ROOT" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
plugin = root / "plugins" / "intent2ship"

def md_body(path):
    return path.read_text().split("---", 2)[2].strip()

def toml_body(path):
    text = path.read_text()
    marker = 'developer_instructions = """'
    rest = text[text.index(marker) + len(marker):]
    if rest.startswith("\n"):
        rest = rest[1:]
    return rest[:rest.rindex('"""')].strip()

def front_value(path, key):
    front = path.read_text().split("---", 2)[1]
    for line in front.splitlines():
        if line.startswith(key + ":"):
            return line.split(":", 1)[1].strip()
    return ""

for name in ("builder", "runner", "reviewer"):
    claude = md_body(plugin / "agents" / f"{name}.md")
    cursor = md_body(plugin / "cursor-agents" / f"{name}.md")
    codex = toml_body(plugin / "codex-agents" / f"{name}.toml")
    if not (claude == cursor == codex):
        print(f"body mismatch: {name}")
        sys.exit(1)

cursor_manifest = json.loads((plugin / ".cursor-plugin" / "plugin.json").read_text())
codex_manifest = json.loads((plugin / ".codex-plugin" / "plugin.json").read_text())
claude_manifest = json.loads((plugin / ".claude-plugin" / "plugin.json").read_text())
if cursor_manifest.get("agents") != "./cursor-agents":
    print("cursor agents path")
    sys.exit(1)
if codex_manifest.get("skills") != "./skills/":
    print("codex skills path")
    sys.exit(1)
versions = {cursor_manifest.get("version"), codex_manifest.get("version"), claude_manifest.get("version")}
if versions != {"0.1.0"}:
    print("manifest versions", versions)
    sys.exit(1)
for path in (
    root / ".cursor-plugin" / "marketplace.json",
    root / ".agents" / "plugins" / "marketplace.json",
):
    if not path.is_file():
        print("missing", path)
        sys.exit(1)

expect = {
    "builder": ("sonnet", "composer-2.5[fast=false]"),
    "runner": ("haiku", "composer-2.5[fast=false]"),
    "reviewer": ("inherit", "inherit"),
}
for name, (claude_model, cursor_model) in expect.items():
    if front_value(plugin / "agents" / f"{name}.md", "model") != claude_model:
        print("claude model", name)
        sys.exit(1)
    if front_value(plugin / "cursor-agents" / f"{name}.md", "model") != cursor_model:
        print("cursor model", name)
        sys.exit(1)

reviewer = (plugin / "cursor-agents" / "reviewer.md").read_text().split("---", 2)[1]
if "readonly: true" not in reviewer:
    print("cursor reviewer readonly")
    sys.exit(1)

builder_toml = (plugin / "codex-agents" / "builder.toml").read_text()
runner_toml = (plugin / "codex-agents" / "runner.toml").read_text()
reviewer_toml = (plugin / "codex-agents" / "reviewer.toml").read_text()
if 'model = "gpt-6.1-sol"' not in builder_toml or 'model_reasoning_effort = "medium"' not in builder_toml:
    print("codex builder model")
    sys.exit(1)
if 'model = "gpt-6-luna"' not in runner_toml or 'model_reasoning_effort = "low"' not in runner_toml:
    print("codex runner model")
    sys.exit(1)
if "model =" in reviewer_toml or "model_reasoning_effort" in reviewer_toml:
    print("codex reviewer should inherit")
    sys.exit(1)

print("prompts match")
PY
}

# Every path a host manifest or marketplace points at must exist, and every manifest must be valid
# JSON. A typo here only shows up when a user installs, so CI catches it first.
check_host_paths() {
  python3 - "$ROOT" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
plugin = root / "plugins" / "intent2ship"

def load(path):
    if not path.is_file():
        print("missing", path.relative_to(root))
        sys.exit(1)
    try:
        return json.loads(path.read_text())
    except ValueError as err:
        print("invalid JSON", path.relative_to(root), err)
        sys.exit(1)

def need(path, what):
    if not path.exists():
        print("missing", what, path.relative_to(root))
        sys.exit(1)

# Marketplaces: each plugin source must resolve to the plugin folder.
claude_mp = load(root / ".claude-plugin" / "marketplace.json")
cursor_mp = load(root / ".cursor-plugin" / "marketplace.json")
codex_mp = load(root / ".agents" / "plugins" / "marketplace.json")
for entry in claude_mp["plugins"] + cursor_mp["plugins"]:
    need(root / entry["source"], "marketplace source")
for entry in codex_mp["plugins"]:
    need(root / entry["source"]["path"], "codex marketplace path")

# Manifests: parse, and every path they name must exist.
claude = load(plugin / ".claude-plugin" / "plugin.json")
cursor = load(plugin / ".cursor-plugin" / "plugin.json")
codex = load(plugin / ".codex-plugin" / "plugin.json")
need(plugin / codex["skills"] / "github" / "SKILL.md", "codex skill")
agents = plugin / cursor["agents"]
need(agents, "cursor agents folder")
for name in ("builder", "runner", "reviewer"):
    need(agents / f"{name}.md", "cursor agent")
    need(plugin / "agents" / f"{name}.md", "claude agent")
    need(plugin / "codex-agents" / f"{name}.toml", "codex agent")
need(plugin / "commands" / "intent2ship.md", "command")
need(plugin / "skills" / "github" / "SKILL.md", "skill")
need(plugin / "skills" / "github" / "scripts" / "wf.sh", "helper script")
if not claude.get("name") == cursor.get("name") == codex.get("name") == "intent2ship":
    print("manifest names differ")
    sys.exit(1)

print("host paths ok")
PY
}

check_host_names() {
  local h
  for h in "Claude Code" "Claude Desktop" "Cursor" "Codex CLI" "Codex app"; do
    grep -q "$h" "$ROOT/README.md" && grep -q "$h" "$ROOT/plugins/intent2ship/skills/github/SKILL.md" \
      || { echo "host not named in README.md and SKILL.md: $h"; return 1; }
  done
  echo "hosts named"
}

# Product names change. Behaviour must key on facts, so the step files may not name a host app.
# (SKILL.md names hosts only to pick a model; setup.md mentions the CLAUDE.md import, which is a feature.)
check_no_names_in_references() {
  local hits
  hits=$(grep -n -i -E 'cursor|codex|chatgpt|claude local' "$ROOT"/plugins/intent2ship/skills/github/references/*.md || true)
  [[ -z $hits ]] || { echo "host names in references: $hits"; return 1; }
  echo "references are name-free"
}

expect "host manifests and prompt bodies" 0 "prompts match" check_hosts
expect "manifest and marketplace paths exist" 0 "host paths ok" check_host_paths
expect "references do not key on host names" 0 "references are name-free" check_no_names_in_references
expect "all five hosts named in README and SKILL.md" 0 "hosts named" check_host_names
finish
