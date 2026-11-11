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
    "builder": ("sonnet", "composer-2.5"),
    "runner": ("haiku", "composer-2.5-fast"),
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

check_host_names() {
  local h
  for h in "Claude Code" "Claude Desktop" "Cursor" "Codex CLI" "ChatGPT Codex"; do
    grep -q "$h" "$ROOT/README.md" && grep -q "$h" "$ROOT/plugins/intent2ship/skills/github/SKILL.md" \
      || { echo "host not named in README.md and SKILL.md: $h"; return 1; }
  done
  echo "hosts named"
}

expect "host manifests and prompt bodies" 0 "prompts match" check_hosts
expect "all five hosts named in README and SKILL.md" 0 "hosts named" check_host_names
finish
