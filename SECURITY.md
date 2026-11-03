# Security policy

## Reporting a vulnerability

Use GitHub's private reporting: open the Security tab of this repository and choose "Report a vulnerability". Please don't open a public issue. Include the version, what you did, and what happened.

## Scope

In scope:

- `wf.sh` and `cloud/setup.sh`: command or argument injection, unsafe path handling, and any way to make the setup script install something other than the pinned commit.
- Skill or agent instructions that let text from an issue, pull request or comment act as an instruction, skip an approval gate, or merge without the user's go-ahead.
- Anything that exposes credentials.

Out of scope:

- General model behaviour (ignoring instructions, wrong output) with no flaw in the files of this repository.
- Vulnerabilities in Claude Code, git or the GitHub CLI. Report those to their maintainers.
- Attacks that need an already compromised machine or account.

## What to expect

This is a one-maintainer project, so response times are best effort. I aim to acknowledge a report within 7 days and to ship a fix or a documented mitigation in a new release. There is no bounty.

## Supported versions

Only the latest release gets fixes.
