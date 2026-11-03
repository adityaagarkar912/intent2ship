# Step 1: Repo setup

Paths such as `references/modes.md` are relative to the skill folder. `wf.sh` is the skill's script (see SKILL.md).

## Step 1: Repo setup (once per repo)

Offer setup when neither `AGENTS.md` nor `CLAUDE.md` has a `## Workflow` section. It is safe to run again: add only what is missing and never overwrite existing content. Do the parts in this order: A, C, B.

**A. Outside the repo** (ask the user first; no commit):
- GitHub mode: create the labels `feature`, `bugfix`, `chore` and `approved`. Local sessions: `gh label create <name> --color <hex> --force`. Claude cloud: see `references/modes.md`. An "already exists" result counts as success.
- Add `.worktrees/` to `.git/info/exclude`, so worktrees stay out of git status without changing the repo.
- Local-only mode: offer the pre-commit hook in `references/modes.md`. It is the only guard in a repo with no remote. `git commit --no-verify` bypasses it, and hooks in `.git/hooks` are not shared.

**C. The user, on GitHub** (the agent does not change repo settings). Ask the user to confirm these are done before part B:
- A ruleset (or branch protection) on `main` that requires a pull request. Set required approvals to 0: GitHub does not let you approve your own PR, so a required approval blocks a solo repo. Approval happens in chat.
- Leave the ruleset's bypass list empty, so admins cannot push to `main` either.
- Allow only the Merge method, in the ruleset and in the repo's merge settings (turn off squash and rebase merging).
- Do not turn on "Require linear history". It blocks merge commits.
- Turn on "Automatically delete head branches".
- Once CI exists, also require its status checks.
- Rulesets need a public repo, or a paid plan for a private one. Without them there is no server-side protection: say so, and rely on this skill's rules.

**B. Inside the repo**, through the flow as `chore/<n>-workflow-setup` (`chore/workflow-setup` in local-only mode). Use a short canned PRD instead of grilling (problem: no agreed workflow; goal: instructions file, PRD folder and checks; scope: those files only). The user still approves the issue and the PR. Contents:
- `AGENTS.md` with `## Workflow` (one line: `Follow the intent2ship skill for every change.`), `## Setup`, `## Checks`, `## Glossary` and `## Decisions`, plus an optional `## Quick checks`. Add only the sections that are missing. If those sections already live only in `CLAUDE.md`, leave them there and do not copy them.
- `CLAUDE.md` containing only `@AGENTS.md`, so Claude Code imports `AGENTS.md`. Write that line only when `CLAUDE.md` is missing. Never overwrite an existing `CLAUDE.md`.
- If a lowercase `agents.md` exists and `AGENTS.md` does not, rename it in this PR with `git mv agents.md agents.tmp && git mv agents.tmp AGENTS.md` (a case-insensitive file system treats the two names as one file). Do the same for `claude.md` and `CLAUDE.md`. If both cases exist for one name, stop and ask.
- `## Setup` and `## Checks`: look in `package.json` scripts, `Makefile`, `pyproject.toml` and similar, then propose the install command (Setup) and the lint, test and build commands (Checks) and get the user's confirmation. If the full suite looks slow, also propose an optional `## Quick checks`: a fast subset, such as lint and unit tests, used for the baseline. Never invent commands. If none are found, leave the section empty and tell the user. If a fresh worktree also needs untracked local files (such as `.env`), have Setup copy them from the main checkout. Never commit them.
- `prd/.gitkeep`.
- The setup PR skips Step 5, because there are no checks yet.
