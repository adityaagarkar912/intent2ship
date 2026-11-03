# Steps 4 to 6: Branch, baseline and build

Paths such as `references/modes.md` are relative to the skill folder. `wf.sh` is the skill's script (see SKILL.md).

## Step 4: Branch

| Issue label | Branch prefix |
|---|---|
| `feature` | `feat/` |
| `bugfix` | `fix/` |
| `chore` | `chore/` |

Name: `<prefix><issue#>-<slug>`, for example `feat/42-csv-export`. Local-only mode has no issue number: `<prefix><slug>`. The slug is lowercase letters, digits and single hyphens, at most 50 characters.

Independent work can run in parallel, one branch and worktree each. Stacked branches (a branch that depends on another unmerged branch) are not part of this workflow. If the work depends on unmerged work, add it to that PRD as items, or wait until it merges and start from the new `main`.

1. Fetch `origin`. If it cannot be reached, warn the user, branch from the last-synced `origin/main`, and remember that the branch has an offline base: Step 7 must fetch and rebase before the PR.
2. Local session, after a successful fetch: fast-forward the local base branch (`git merge --ff-only origin/main` in the main checkout), but only if that checkout is clean and on the base branch. Otherwise warn and skip. Always branch from `origin/main`, never from local `main`.
3. Create the branch with no upstream tracking, so it does not track `origin/main`:
   - Local session (Claude local, Cursor local, Codex local), from the main checkout: `git worktree add --no-track .worktrees/<prefix-without-slash>-<issue#>-<slug> -b <branch> origin/main`. Work only inside that directory. If the repo has a `.gitmodules` file, tell the user that git's docs advise against multiple worktrees of a repository with submodules, and ask whether to use an in-place branch (as on an isolated VM) instead.
   - Cursor cloud, Codex cloud, ChatGPT Work, and Claude cloud: `git switch --no-track -c <branch> origin/main`. Use this name, not a host default such as `claude/`. Skip worktrees; the VM is already isolated. Whether Claude cloud accepts pushes of branches without the `claude/` prefix is unverified: if a push is refused, tell the user.
4. Run the `## Setup` command from the instructions file inside the new worktree. Read `AGENTS.md` when it has `## Setup`, otherwise `CLAUDE.md`. A fresh worktree has no installed dependencies. If Setup fails, stop and report it; do not go on to Step 5.
5. First commit: `prd/<slug>.md` taken from the issue's PRD block (the approved chat text in local-only mode), plus any glossary terms and repo-wide decisions from Step 2 added to the instructions file (`AGENTS.md`, or `CLAUDE.md` when that file holds the sections). Run the stray-file check from Step 6 first.

Pushing: on Cursor cloud, Codex cloud, ChatGPT Work, and Claude cloud, push after the first commit and after each checklist item (`git push -u origin <branch>`). An expired cloud environment keeps the conversation but loses unpushed commits. On a local session, push only when opening the PR (Step 8).

Resuming an existing branch: reuse its worktree if it has one. Otherwise fetch and add a worktree for the existing branch (isolated VM: `git switch <branch>`), then compare it with `origin/<branch>` before continuing. `wf.sh resume <branch>` does this.

## Step 5: Baseline

Before changing code, run the commands in `## Quick checks` if that section exists, otherwise `## Checks`. Read them from the base branch, not from this branch. Prefer `git show origin/main:AGENTS.md` when that file has the section, otherwise `git show origin/main:CLAUDE.md` (local-only: `main`). The workflow setup PR is the one exception: it skips this step.

1. Run each command in the worktree and report one line per check, for example `lint ✓ · test ✓ · build ✓`. Prefer the `runner` subagent: pass the exact commands, the absolute worktree path, and the model from the Models section in SKILL.md. It reports PASS, FAIL or FLAKY per command plus the first failing lines, so test output stays out of this conversation. If the subagent cannot be started, run the commands yourself.
2. A failing check is rerun once (the runner does this itself). If it passes the second time, count it as flaky and continue.
3. If a check still fails, stop and report it. Do not build on a red baseline unless the user says to. Offer these options: proceed with the failures recorded; stop and make a separate chore for the fix; or, if the fix is tiny and blocks this work, add it to this issue as an amendment.
4. In GitHub mode, post the result as a short comment on the issue: the commit, which checks ran, and which failed or were flaky. Step 7 reports only new failures against it.
5. If `## Checks` is empty, ask the user for the commands and add them in this branch.

## Step 6: Build

Work through the issue checklist one item at a time. For each item:

1. **Implement it.** Delegate it or do it yourself (see below). Stay inside the issue's scope. When the project has a test suite, add or update tests for the item's acceptance criteria; a bugfix starts with a test that fails before the fix. A new dependency is the user's decision: ask in chat first, and record the reason in the commit body.
2. **Check.** Run the quick checks as in Step 5 (the runner subagent for long output).
3. **Review what is staged.** Run the stray-file check below, stage only the files that belong to the item, and unstage anything else (`.env`, build output). Never commit secrets.
4. **Commit:** `<type>: <summary> (#<issue>)` in GitHub mode, with type `feat`, `fix`, `chore`, `refactor`, `test` or `docs` and an imperative summary of at most 72 characters. Put the reason for any non-obvious choice in the commit body; Step 8 builds the PR's Decisions from the bodies. Never bypass hooks with `--no-verify`; if a hook fails, fix the cause.
5. **Isolated VM only: push** (`git push -u origin <branch>`). That is Cursor cloud, Codex cloud, ChatGPT Work, and Claude cloud.
6. **Tick the item on the issue** (GitHub mode): read the current issue body right before, change only that item's checkbox, and write it back. Update the todo list.

A small change the user asks for is an amendment (Step 3): one more item through the same loop. Anything else new that you or a subagent notice is a follow-up: add it to the todo list and tell the user at once. Follow-ups go in the PR body (Step 8), and Step 9 offers to turn them into one chore issue. If building shows that the PRD is wrong or incomplete, stop and tell the user; a change to the acceptance criteria follows the amendment rule.

The stray-file check: before every commit, list new or untracked `.md` files with `git status --porcelain -- '*.md'` and, on the branch, `git diff --name-only --diff-filter=A <base>...HEAD -- '*.md'`. Anything other than `AGENTS.md`, `CLAUDE.md`, and `prd/*.md` is stray (for example `CONTEXT.md` or a `docs/adr/` file from `grill-with-docs`). Delete it and tell the user. Existing files that were only modified are fine.

### Delegating to the builder

Delegate an item to the `builder` subagent when it is well defined: specific, testable acceptance criteria, a known file area or pattern to follow, no open design choices, and one self-contained item. Use the model from the Models section in SKILL.md. Tell the user in one line, for example "Delegating item 2 to the builder". Do the item yourself when it is ambiguous or needs new design, touches security-sensitive code (auth, input validation, crypto), means debugging an unknown root cause, or is a tiny change. If the subagent cannot be started, do the item yourself and tell the user.

The builder starts with no conversation history and cannot ask the user questions. The delegation message must contain: the issue number, the item and its acceptance criteria, the PRD path, the absolute worktree path, the exact check commands (read from the base branch), and any decision already made in chat. Record `git rev-parse HEAD` before delegating.

The builder never stages, commits or pushes. Its report ends in one of three statuses:
- DONE: review its diff yourself, then continue the loop at step 2 and re-run the checks; do not rely on its own check report.
- BLOCKED: ask the user its question, then resume it or do the item yourself.
- PARTIAL (it hit its turn limit): resume it, or finish the item yourself.

Afterwards check that `HEAD` has not moved. If it has, tell the user and do not push. If the checks fail on its result, retry it once with the failure output; if it still fails, do the item yourself.
