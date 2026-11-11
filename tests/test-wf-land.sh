#!/usr/bin/env bash
# shellcheck disable=SC2164,SC2034  # test scripts: a failed cd shows up as a failed assertion
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WF_SRC="${WF:-$ROOT/plugins/intent2ship/skills/github/scripts/wf.sh}"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
REAL_GIT=$(command -v git)
T=$(cd "$(mktemp -d)" && pwd -P); cd "$T"
cp "$WF_SRC" "$T/wf.sh"; W="bash $T/wf.sh"
PASS=0; FAIL=0
expect() { local l=$1 ex=$2 pat=$3; shift 3; local out; out=$("$@" 2>&1); local rc=$?
  if [[ $rc -eq $ex ]] && { [[ $pat == - ]] || grep -q -- "$pat" <<<"$out"; }; then PASS=$((PASS+1)); echo "ok   $l"
  else FAIL=$((FAIL+1)); echo "FAIL $l (rc=$rc, wanted $ex, pattern '$pat')"; echo "$out" | tail -5 | sed 's/^/       /'; fi; }
gi() { git -c user.email=t@t -c user.name=t "$@"; }
mk() { rm -rf "$1"; git init -q -b main "$1"; git -C "$1" config user.email t@t; git -C "$1" config user.name t; seq 1 10 > "$1/f"; git -C "$1" add f; git -C "$1" commit -qm init; }

echo "## cleanup, local-only"
mk lo; cd lo
$W start feat - a >/dev/null 2>&1; ( cd .worktrees/feat-a && echo x > x && git add x && git commit -qm "feat: x" )
expect "unmerged branch refused"      1 "is not merged"        $W cleanup feat/a
git merge -q --no-ff -m "Merge feat/a" feat/a
expect "merged: cleans up"            0 "cleaned feat/a"       $W cleanup feat/a
expect "worktree + branch gone"       0 -  bash -c '[ "$(git worktree list | wc -l)" -eq 1 ] && [ -z "$(git branch --list "feat/*")" ]'
expect "second run: no such branch"   1 "no such local branch" $W cleanup feat/a

$W start fix - sq >/dev/null 2>&1; ( cd .worktrees/fix-sq && echo s > s && git add s && git commit -qm "fix: s" )
git merge -q --squash fix/sq; git commit -qm "squashed fix"
expect "squash-merged refused"        1 "squashed or rebased"  $W cleanup fix/sq
git worktree remove --force .worktrees/fix-sq; git branch -q -D fix/sq

$W start chore - dirty >/dev/null 2>&1; ( cd .worktrees/chore-dirty && echo d > d && git add d && git commit -qm "chore: d" )
git merge -q --no-ff -m "Merge chore/dirty" chore/dirty; echo untracked > .worktrees/chore-dirty/u
expect "dirty worktree refused"       1 "uncommitted changes"  $W cleanup chore/dirty
expect "refused leaves branch"        0 -  git show-ref --verify --quiet refs/heads/chore/dirty
rm .worktrees/chore-dirty/u; expect "then cleans"  0 "cleaned"  $W cleanup chore/dirty

git branch feat/mainco; git merge -q --no-ff -m "Merge" feat/mainco 2>/dev/null; git checkout -q feat/mainco
cd "$T/lo" 2>/dev/null; expect "checked out in main checkout refused" 1 "main checkout" $W cleanup feat/mainco
git checkout -q main
expect "base branch refused"          1 "branch must look like" $W cleanup main
expect "invalid name refused"         1 "branch must look like" $W cleanup --force
expect "cloud: nothing to do"         0 "nothing to clean up"   env CLAUDE_CODE_REMOTE=true bash -c "$W cleanup feat/zzz"

echo "## land-local range-diff summary"
cd "$T"; mk rc; cd rc
$W start feat - clean >/dev/null 2>&1; ( cd .worktrees/feat-clean && sed -i.bak '1s/.*/one/' f && rm -f f.bak && git commit -qam "feat: edit line 1" )
echo extra > extra; git add extra; git commit -qm "main: unrelated file"
expect "clean rebase says clean, exit 3" 3 "rebase is clean" $W land-local feat/clean T --yes
expect "second run lands"             0 "landed feat/clean" $W land-local feat/clean T --yes

cd "$T"; mk rp; cd rp
$W start feat - near >/dev/null 2>&1; ( cd .worktrees/feat-near && sed -i.bak '5s/.*/five-feature/' f && rm -f f.bak && git commit -qam "feat: edit line 5" )
sed -i.bak '7s/.*/seven-main/' f && rm -f f.bak; git commit -qam "main: edit line 7"
expect "context change flagged, exit 3"  3 "rebase changed patches" $W land-local feat/near T --yes

echo "## cleanup, GitHub mode (git shim)"
cd "$T"; mkdir shim; export WF_BARE="$T/up.git"
cat > shim/git <<'EOF'
#!/bin/bash
net=0
for a in "$@"; do case "$a" in fetch|ls-remote|push) net=1;; esac; done
if [[ $net -eq 1 ]]; then exec @REAL_GIT@ -c "url.file://$WF_BARE.insteadOf=https://github.com/o/r.git" "$@"; fi
exec @REAL_GIT@ "$@"
EOF
sed -i.bak "s#@REAL_GIT@#$REAL_GIT#" shim/git && rm -f shim/git.bak; chmod +x shim/git; with_shim() { env PATH="$T/shim:$PATH" "$@"; }
git init -q --bare -b main up.git
git clone -q up.git seed 2>/dev/null; ( cd seed && git checkout -q -b main 2>/dev/null; seq 1 5 > f; git add f; gi commit -qm c1; git push -q origin main )
git clone -q up.git cl 2>/dev/null; cd cl; git remote set-url origin https://github.com/o/r.git
with_shim $W start feat 5 gh >/dev/null 2>&1; ( cd .worktrees/feat-5-gh && echo g > g && git add g && gi commit -qm "feat: g (#5)" && git push -q "$WF_BARE" feat/5-gh:feat/5-gh )
expect "not merged on origin: refused"  1 "is not merged into origin/main" with_shim $W cleanup feat/5-gh
( cd "$T/seed" && git fetch -q origin && git checkout -q main && gi merge -q --no-ff -m "Merge feat/5-gh" origin/feat/5-gh && git push -q origin main )   # "GitHub merges the PR"
expect "merged on origin: cleans up"    0 "cleaned feat/5-gh"  with_shim $W cleanup feat/5-gh
expect "local main fast-forwarded"      0 -  bash -c '[ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ] && [ -f g ]'
expect "worktree gone"                  0 -  bash -c '[ ! -d .worktrees/feat-5-gh ]'
cd "$T"; rm -rf off; git clone -q up.git off 2>/dev/null; cd off; git config user.email t@t; git config user.name t
git branch feat/9-x origin/main; git remote set-url origin https://github.com/nonexistent-zz/none.git
expect "offline: cannot verify, refused" 1 "cannot reach origin" env GIT_TERMINAL_PROMPT=0 bash -c "$W cleanup feat/9-x"

echo; echo "passed=$PASS failed=$FAIL"
