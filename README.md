# intent2ship

A plugin that takes a coding request from intent to a merged change through approval gates. You approve a PRD, then an issue, then a pull request. Nothing is coded before the issue is approved, and nothing merges until you tell it to.

Between the gates the work happens on a labeled branch in its own git worktree: small commits, checks before and after, and a review you can follow. It works on GitHub repos from Claude Code, Cursor, and Codex, including cloud sessions, and on repos that have no remote. The skill and the helper script are shared. Each host has its own manifest and its own model for the builder, runner, and reviewer.

## The flow

| Step | What happens | You approve |
|---|---|---|
| 1 | One-time repo setup: labels, `AGENTS.md` sections, `prd/` folder | The setup change, like any other |
| 2 | A PRD, written through questions to you | The PRD |
| 3 | A GitHub issue with a checklist and the PRD | The issue |
| 4 | A branch and worktree from `origin/main` | |
| 5 | Baseline checks before any change | |
| 6 | The build, one checklist item at a time | |
| 7 | Review: rebase, full checks, acceptance table, diff walkthrough | |
| 8 | A pull request | The PR |
| 9 | A merge commit on your instruction, then cleanup | Your "merge" |

Every change goes through all nine steps, including one-line fixes.

## Install

Ask for a change as usual after installing. The first run in a repo offers the one-time setup. Setup writes the workflow sections in `AGENTS.md`. When `CLAUDE.md` is missing, setup adds a one-line `@AGENTS.md` import so Claude Code reads the same file. Check commands still come from the base branch copy of that file.

### Claude Code

```
/plugin marketplace add adityaagarkar912/intent2ship#v0.1.0
/plugin install intent2ship@intent2ship
```

Then ask for a change, or run `/intent2ship:github`.

For Claude cloud sessions, paste `cloud/setup.sh` into the environment's setup script field. It installs one pinned release and checks the commit SHA before installing. Set `TAG` and `SHA` in the script first.

### Cursor

In Customize, import this repository and install `intent2ship`. Then ask for a change, or run `/intent2ship`.

### Codex

```
codex plugin marketplace add adityaagarkar912/intent2ship
```

Enable `intent2ship`, then ask for a change. The default prompt follows the github skill.

Codex plugin install does not register custom agents. Copy the role files yourself:

```
mkdir -p ~/.codex/agents
cp plugins/intent2ship/codex-agents/*.toml ~/.codex/agents/
```

Until those files are copied, the skill still names the model when it spawns a subagent, and the delegation message includes that role's rules.

## Requirements

- git and bash. Tested with git 2.43.
- The GitHub CLI (`gh`) for GitHub repos. Claude cloud uses `gh api` because its proxy blocks `gh pr` and `gh issue`. Cursor and Codex use `gh`, and fall back to `gh api` only when `gh` is blocked.
- Claude Code, Cursor, or Codex. The Claude plugin was validated with Claude Code 2.1.316.

## Subagents

| Agent | Claude | Cursor | Codex | Job |
|---|---|---|---|---|
| `builder` | Sonnet | `composer-2.5` | `gpt-6.1-sol`, medium | Implements one checklist item. Never stages, commits or pushes. |
| `runner` | Haiku | `composer-2.5-fast` | `gpt-6-luna`, low | Runs the check commands and returns pass, fail or flaky with the first failing lines, so test output stays out of the main conversation. |
| `reviewer` | Your session's model | Inherits the session | Inherits the parent | Read-only review of the whole diff against the PRD. |

If a named model is not available on the account, the parent model is used and the session says so.

The main session reviews every diff, re-runs the checks, commits, and keeps all approvals. The plugin adds about 270 tokens to a session; the skill itself is about 1,000 tokens when it runs, plus the reference file for the current step.

## Status

v0.1.0 is a pre-release.

Verified:

- More than 110 shell tests covering the helper script, the setup script and the version check.
- `claude plugin validate --strict` on the marketplace and the plugin.
- The plugin installs from a pinned clone and loads one skill and three agents.
- Command syntax checked against the current `gh` and GitHub REST documentation.

Not yet verified:

- Cloud sessions: pushing `feat/` branches, loading the plugin's agents, and the REST pull request lookup.
- `gh pr merge` from a worktree against a live repository.
- Installing the Cursor plugin from Customize, and installing the Codex plugin from `codex plugin marketplace add`.
- Codeberg and other git hosts. A separate skill is planned.

## Security

- Only your chat messages count as instructions. Text in issues, pull requests and comments is data.
- The helper script validates branch names and refuses unexpected input. The cloud setup script installs one pinned commit and stops if the SHA differs.
- Check commands are read only from the base branch's `AGENTS.md`, or from `CLAUDE.md` when that file still holds the sections.

To report a vulnerability, see [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
