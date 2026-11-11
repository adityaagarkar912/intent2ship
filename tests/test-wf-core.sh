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
mk() { rm -rf "$1"; git init -q -b main "$1"; git -C "$1" config user.email t@t; git -C "$1" config user.name t; echo a > "$1/a"; git -C "$1" add a; git -C "$1" commit -qm init; }
# expect <label> <expected-exit> <grep-pattern or -> cmd...
expect() { local l=$1 ex=$2 pat=$3; shift 3; local out; out=$("$@" 2>&1); local rc=$?
  if [[ $rc -eq $ex ]] && { [[ $pat == - ]] || grep -q -- "$pat" <<<"$out"; }; then PASS=$((PASS+1)); echo "ok   $l"
  else FAIL=$((FAIL+1)); echo "FAIL $l (rc=$rc, wanted $ex, pattern '$pat')"; echo "$out" | tail -4 | sed 's/^/       /'; fi; }

mk r1; cd r1
echo "## validation (#4 #5)"
expect "slug --foo rejected"         1 "slug must be"        $W start feat 1 --foo
expect "slug -- rejected"            1 "slug must be"        $W start feat 1 --
expect "slug a/../b rejected"        1 "slug must be"        $W start feat 1 "a/../b"
expect "slug uppercase rejected"     1 "slug must be"        $W start feat 1 "Big"
expect "slug trailing dash"          1 "slug must be"        $W start feat 1 "abc-"
expect "slug too long"               1 "slug must be"        $W start feat 1 "$(printf 'a%.0s' {1..51})"
expect "issue not numeric"           1 "issue must be"       $W start feat '1;touch PWNED' x
[[ ! -e PWNED ]] && echo "ok   no injected file" && PASS=$((PASS+1)) || { echo "FAIL PWNED exists"; FAIL=$((FAIL+1)); }
expect "type invalid"                1 "type must be"        $W start hotfix 1 x
expect "no junk branches created"    0 -                     bash -c '[ -z "$(git branch --list "feat/*")" ]'

echo "## env (#2 #7 #9 #10)"
expect "env local-only"              0 "mode=local .*online=n/a" $W env
git remote add origin 'git@gitlab.com:evil/github.com.git'
expect "lookalike scp host -> other" 0 "mode=other"          $W env
git remote set-url origin 'https://github.com.evil.com/o/r.git'
expect "lookalike subdomain -> other" 0 "mode=other"         $W env
git remote set-url origin 'https://notgithub.com/o/r.git'
expect "suffix host -> other"        0 "mode=other"          $W env
for u in 'https://github.com/o/r.git' 'git@github.com:o/r.git' 'ssh://git@github.com/o/r' 'https://user:tok@github.com/o/r' 'https://GitHub.com/o/r' 'ssh://git@github.com:22/o/r'; do
  git remote set-url origin "$u"; expect "github url: $u" 0 "mode=github" $W env; done
git remote set-url origin 'git@gitlab.com:evil/github.com.git'
expect "start refuses non-github"    1 "not GitHub"          $W start feat 1 ok
cd /tmp; expect "env outside repo fails (#7)" 1 "not inside a git repository" $W env
expect "start outside repo fails"    1 "not inside a git repository" $W start feat 1 x

echo "## paths with spaces (#1) + local start/land"
cd "$T"; mk "r 2 sp"; cd "r 2 sp"
expect "env quotes spaced path"      0 "main_checkout=\"$(pwd -P)\"" $W env
expect "start in spaced path"        0 "worktree .*r 2 sp/.worktrees/feat-spaced" $W start feat - spaced
( cd ".worktrees/feat-spaced" && echo b > b && git add b && git commit -qm b )
expect "no tracking set (#6)"        0 -  bash -c '[ -z "$(git config --get branch.feat/spaced.merge)" ]'
expect "land in spaced path"         0 "landed feat/spaced"  $W land-local feat/spaced T --yes
expect "worktree and branch gone"    0 -  bash -c '[ "$(git worktree list | wc -l)" -eq 1 ] && [ -z "$(git branch --list "feat/*")" ]'
expect "merge commit exists"         0 "Merge feat/spaced: T" git log --oneline -3

echo "## land guards (#3 #4 #10)"
cd "$T"; mk r4; cd r4
expect "option-like branch rejected" 1 "branch must look like" $W land-local --force T --yes
expect "base into itself rejected"   1 "branch must look like" $W land-local main T --yes
expect "nonexistent branch"          1 "no such branch"      $W land-local feat/nope T --yes
expect "bad third arg"               1 "must be --yes"       $W land-local feat/x T maybe
git branch feat/x
git checkout -q --detach
expect "detached main checkout"      1 "detached HEAD"       $W land-local feat/x T --yes
git checkout -q main
expect "no stdin, no --yes blocked"  1 "no input"            bash -c "$W land-local feat/x T </dev/null"
echo dirty > a
expect "dirty main checkout"         1 "uncommitted"         $W land-local feat/x T --yes
git checkout -q -- a

echo "## rebase: conflict (#8) and moved main (#12)"
cd "$T"; mk r3; cd r3
$W start feat - conf >/dev/null 2>&1
echo x > .worktrees/feat-conf/a; git -C .worktrees/feat-conf commit -qam "x"
echo y > a; git commit -qam "y"
expect "conflict message"            1 "Nothing was merged. Resolve" $W land-local feat/conf T --yes
expect "main untouched, no merge"    0 -  bash -c '[ "$(git log --oneline | wc -l)" -eq 2 ] && [ -z "$(git status --porcelain)" ]'
expect "worktree left mid-rebase"    0 "rebase in progress"  git -C .worktrees/feat-conf status
git -C .worktrees/feat-conf rebase --abort

cd "$T"; mk r5; cd r5
$W start feat - mv >/dev/null 2>&1
echo b > .worktrees/feat-mv/b; git -C .worktrees/feat-mv add b; git -C .worktrees/feat-mv commit -qm b
echo c > c; git add c; git commit -qm c        # main moves
expect "moved main: rebase, exit 3"  3 "Re-run the checks" $W land-local feat/mv T --yes
expect "branch still exists"         0 -  git show-ref --verify --quiet refs/heads/feat/mv
expect "second run lands"            0 "landed feat/mv"      $W land-local feat/mv T --yes
expect "history is linear + merge"   0 -  bash -c 'git log --oneline --graph | grep -q "Merge feat/mv"'

echo "## branch with no worktree uses temp worktree"
cd "$T"; mk r6; cd r6
git branch feat/orphan; git checkout -q feat/orphan; echo o > o; git add o; git commit -qm o; git checkout -q main
expect "land without worktree"       0 "landed feat/orphan" $W land-local feat/orphan T --yes
expect "temp worktree removed"       0 -  bash -c '[ "$(git worktree list | wc -l)" -eq 1 ]'

echo "## offline start (#6): github remote unreachable, local copy of origin/main exists"
cd "$T"; git init -q --bare up.git; git clone -q up.git cl 2>/dev/null; cd cl
git config user.email t@t; git config user.name t; git checkout -q -b main 2>/dev/null; echo a>a; git add a; git commit -qm init; git push -q origin main
git remote set-url origin 'https://github.com/nonexistent-zz/none.git'
expect "env says offline"            0 "online=no"           $W env
expect "offline start warns, works"  0 "offline base"        $W start feat 7 off
expect "branch not tracking origin/main" 0 -  bash -c '[ -z "$(git config --get branch.feat/7-off.merge)" ]'
expect "worktree exists"             0 -  test -d .worktrees/feat-7-off
cd "$T"; mk nofetch; git -C nofetch remote add origin 'https://github.com/nonexistent-zz/none.git'
expect "offline, no origin/main ref" 1 "no local copy"       bash -c "cd nofetch && $W start feat 8 x"

echo "## cloud path: reachable remote, --no-track (#6)"
cd "$T"; git -C up.git symbolic-ref HEAD refs/heads/main; rm -rf cl2; git clone -q up.git cl2 2>/dev/null; cd cl2; git config user.email t@t; git config user.name t
expect "cloud start"                 0 "^branch feat/9-cloud"  env CLAUDE_CODE_REMOTE=true bash -c "$W start feat 9 cloud"
expect "cloud: on new branch"        0 "feat/9-cloud"        git branch --show-current
expect "cloud: no tracking"          0 -  bash -c '[ -z "$(git config --get branch.feat/9-cloud.merge)" ]'
expect "cloud env says cloud"        0 "session=cloud mode=github" env CLAUDE_CODE_REMOTE=true bash -c "$W env"

echo "## no origin/HEAD, no local main, but origin/main exists"
cd "$T"; git -C up.git symbolic-ref HEAD refs/heads/nope; rm -rf cl3; git clone -q up.git cl3 2>/dev/null; cd cl3
git config user.email t@t; git config user.name t
expect "fallback finds origin/main"  0 "base=main"           env CLAUDE_CODE_REMOTE=true bash -c "$W env"
expect "cloud start via fallback"    0 "^branch feat/11-fb"  env CLAUDE_CODE_REMOTE=true bash -c "$W start feat 11 fb"
echo "## check (#11) unchanged"
expect "check pass"                  0 "PASS"                $W check 'true'
expect "check fail exit 1"           1 "FAIL"                $W check 'false' 'true'
expect "check no args"               1 "usage"               $W check

echo; echo "passed=$PASS failed=$FAIL"
