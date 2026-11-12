# Commands by mode

`<o>/<r>` is the owner and repo parsed in Step 0.

## GitHub mode, local session

Local sessions use these commands. Cloud sessions use them too, unless `gh` is blocked.

| Action | Command |
|---|---|
| Create labels | `gh label create feature --color 1d76db --force`, then `bugfix` (`d73a4a`), `chore` (`cfd3d7`), `approved` (`0e8a16`) |
| Create issue | `gh issue create --title "<t>" --body-file <f> --label <type>` |
| Add label | `gh issue edit <n> --add-label approved` |
| Comment on issue | `gh issue comment <n> --body-file <f>` |
| Create PR | `gh pr create --base main --head <branch> --title "<t>" --body-file <f> --label <type>` |
| Land | `gh pr merge <n> --merge --match-head-commit <sha>`, run from the main checkout, without `--delete-branch` |
| Check issue | `gh issue view <n> --json state` |

`--match-head-commit` makes the merge fail if the head is not the approved SHA. `gh pr merge` can exit non-zero after a successful merge when worktrees are involved (it tries to switch the local checkout to the base branch), so check the state with `gh pr view <n> --json state,mergeCommit` before treating it as failed.

## GitHub mode, REST fallback (when `gh` is blocked)

This column is for sessions where `gh pr` and `gh issue` fail because a proxy blocks GraphQL, as in Claude cloud. Test with one read-only call such as `gh pr list`. Use these REST commands only when `gh` is actually blocked; otherwise use the local CLI commands above.

Use the built-in GitHub tools, or REST through `gh api`:

| Action | Command |
|---|---|
| Create label | `gh api repos/<o>/<r>/labels -f name=<n> -f color=<hex>` for each of the four labels and colors above. A 422 "already exists" is fine. |
| Create issue | `gh api repos/<o>/<r>/issues -f title="<t>" -F body=@<file> -f "labels[]=<type>"` |
| Add label | `gh api repos/<o>/<r>/issues/<n>/labels -f "labels[]=approved"` |
| Comment on issue | `gh api repos/<o>/<r>/issues/<n>/comments -F body=@<file>` |
| Create PR | `gh api repos/<o>/<r>/pulls -f title="<t>" -f head=<branch> -f base=main -F body=@<file>` |
| Label PR | `gh api repos/<o>/<r>/issues/<pr#>/labels -f "labels[]=<type>"` |
| Land | `gh api -X PUT repos/<o>/<r>/pulls/<n>/merge -f merge_method=merge -f sha=<head-sha>` |
| Check issue | `gh api repos/<o>/<r>/issues/<n> --jq .state` |

Verify the merge with `gh api repos/<o>/<r>/pulls/<n> --jq '{state,merged,merge_commit_sha}'`.

The proxy rejects branch deletion, so the remote branch is removed by the repo's "Automatically delete head branches" setting. If that setting is off, tell the user which branch to delete.

Cloud sessions can expire. The issue checklist and the `approved` label are the durable state: keep them current so a new session can resume.

## Local-only mode (no remote)

| Step | Replacement |
|---|---|
| Issue | Show the issue text in chat. Approval in chat. |
| Task list | Session todo list only. Remind the user it is lost when the session ends. |
| PR | Show `git diff main...<branch> --stat` and walk the diff. Approval in chat. |
| Land | `wf.sh land-local <branch> "<title>" --yes`: it rebases (exit 3 with a range-diff summary if it moved the branch), merges with `--no-ff`, and cleans up. For a branch merged by hand: `wf.sh cleanup <branch>`. |

## Local guard: pre-commit hook (local-only mode)

Offer it during setup, and install only if the user agrees. Write `.git/hooks/pre-commit`, make it executable, and never overwrite an existing hook.

Behaviour (tested): exit non-zero with a clear message when the current branch is the base branch and `.git/MERGE_HEAD` does not exist. That blocks direct commits on the base branch, and still allows branch commits, clean `--no-ff` merges (git runs `pre-merge-commit`, not `pre-commit`) and conflict-resolution commits (`MERGE_HEAD` exists). `git commit --no-verify` bypasses it, and hooks are not shared between clones.

## Duplicate check and approval history (GitHub mode)

Before creating an issue, search open and closed issues by keyword.

- `gh` works: `gh issue list --state all --search "<keywords>" --limit 20`
- When `gh issue` is blocked: `gh api --method GET search/issues -f q="repo:<o>/<r> is:issue <keywords>" --jq '.items[] | "#\(.number) \(.state) \(.title)"'`

When resuming, list every time the `approved` label was applied, so a label added by someone else is visible:

`gh api repos/<o>/<r>/issues/<n>/events --paginate --jq '.[] | select(.event=="labeled" and .label.name=="approved") | [.actor.login, .created_at] | @tsv'`

Show the user the result and get one chat confirmation. The events call is plain REST, so it also works where `gh` is blocked.

## PR lookup, update and CI results (GitHub mode)

Local session:
- Find a PR for the branch: `gh pr list --head <branch> --state all --json number,state,url`
- Update it: `gh pr edit <n> --title "<t>" --body-file <f>`
- CI results: `gh pr checks <n> --json name,bucket,link`. The bucket is pass, fail, pending, skipping or cancel, and exit code 8 means checks are still pending.

When `gh pr` is blocked, use REST:
- Find a PR for the branch: `gh api "repos/<o>/<r>/pulls?head=<o>:<branch>&state=all" --jq '.[] | "#\(.number) \(.state) \(.html_url)"'`
- Update it: `gh api --method PATCH repos/<o>/<r>/pulls/<n> -f title="<t>" -F body=@<file>`
- CI results: `gh api repos/<o>/<r>/commits/<sha>/check-runs --jq '.check_runs[] | "\(.name) \(.status) \(.conclusion)"'`. Some CI systems report through commit statuses instead; read those with `gh api repos/<o>/<r>/commits/<sha>/status --jq .state`.

