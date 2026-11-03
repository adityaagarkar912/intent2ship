# Steps 2 and 3: PRD and issue

Paths such as `references/modes.md` are relative to the skill folder. `wf.sh` is the skill's script (see SKILL.md).

## Step 2: PRD

Ask the depth first, unless the user already said it:

| Depth | Use when | Grilling |
|---|---|---|
| Quick | Idea is fully formed | 3 to 5 questions on gaps and acceptance criteria |
| Standard | Idea is clear, details are not | Walk the decision tree one branch at a time |
| Deep | Idea is vague | Standard, plus edge cases, non-functional requirements, risks, out-of-scope |

Propose Quick for obviously small changes (a typo, a one-line fix, a chore) and let the user confirm.

Ask one question at a time and give your recommended answer with each. In Cursor, use the question tool when it is available. Before asking, check whether the code already answers the question. Always ask whether the work depends on any unmerged change; if it does, see Step 4.

If the `grill-with-docs` skill is available, use it for the questioning, with this redirect: it must not create `CONTEXT.md`, ADR files or any other file. Collect glossary terms and decisions in the conversation; they are written in Step 4. When the grill ends, run the stray-file check from Step 6 and delete anything it flags.

PRD templates by issue type. Omit any section with nothing to say; do not write filler such as "None". Depth only controls how many questions you ask.

Feature:

```
# <Title>
## Problem
## Goal
## Scope
## Out of scope
## Decisions
## Acceptance criteria
## Risks
```

Bugfix (acceptance criteria must include a test that fails before the fix):

```
# <Title>
## Problem
## Steps to reproduce
## Expected behaviour
## Acceptance criteria
## Out of scope
```

Chore, or a bundle of chores:

```
# <Title>
## Problem
## Items
## Acceptance criteria
```

Show the draft in chat and revise until the user approves it. Nothing is written to disk yet.

## Step 3: Issue

One issue is one PRD is one branch is one PR. A PRD can hold many work items: each becomes a checklist item with its own commit or commits. If the items are independent and the PR would be hard to review, offer to split them into separate PRDs; the user decides.

A bundle of small chores is one `chore` issue with one checklist item per chore. Only chores are bundled: features and bugfixes get their own issue.

1. Search for duplicates: open and closed issues by keyword (commands in `references/modes.md`). If one overlaps, show it and ask whether to continue it instead.
2. Create the issue:
   - Title: sentence case, under 70 characters.
   - Label: `feature`, `bugfix` or `chore`.
   - Body: two-line summary, the task checklist (`- [ ]`) in plain language, acceptance criteria, then the full approved PRD inside `<details><summary>PRD</summary> ... </details>`.
3. Share the link and stop. The user reviews it on GitHub and approves in chat.
4. Re-read the issue and compare it with what you posted. If it differs, show the user the difference. From here on the issue is the source of truth.
5. Add the `approved` label and mirror the checklist into the session todo list. In Cursor, use the todo tool.

Before Step 4 and again before Step 8, re-read the issue. If its PRD block no longer matches `prd/<slug>.md`, stop and show the difference. The user decides which side wins.

Local-only mode has no issue: show the same content in chat, and write the PRD file from the approved chat text.

### Resuming

When a session finds an issue labelled `approved` with unfinished work, list who applied the label and when (issue events, in `references/modes.md`) and get one chat confirmation before continuing. The label alone is never enough.

### Amendments

While the issue is open and its PR is not merged, the user may ask for a small change in chat. Add it to the issue checklist marked "(added)", commit it on the same branch, and list it in the PR's Decisions log. No new issue or PRD. If the change alters the acceptance criteria or scope, it is not small: update the PRD and the issue, and get the user's approval of the issue again before continuing. After merge or close, it is a new issue; small leftovers can go in the next chore bundle.
