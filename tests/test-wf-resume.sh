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
  else FAIL=$((FAIL+1)); echo "FAIL $l (rc=$rc, wanted $ex, pattern '$pat')"; echo "$out" | tail -4 | sed 's/^/       /'; fi; }
gi() { git -c user.email=t@t -c user.name=t "$@"; }

# shim: network ops against the fake github URL go to a local bare repo
mkdir shim; export WF_BARE="$T/up.git"
cat > shim/git <<'EOF'
#!/bin/bash
net=0
for a in "$@"; do case "$a" in fetch|ls-remote|push) net=1;; esac; done
if [[ $net -eq 1 ]]; then exec @REAL_GIT@ -c "url.file://$WF_BARE.insteadOf=https://github.com/o/r.git" "$@"; fi
exec @REAL_GIT@ "$@"
EOF
sed -i.bak "s#@REAL_GIT@#$REAL_GIT#" shim/git && rm -f shim/git.bak; chmod +x shim/git
with_shim() { env PATH="$T/shim:$PATH" "$@"; }

git init -q --bare -b main up.git
git clone -q up.git seed 2>/dev/null; cd seed; git checkout -q -b main 2>/dev/null; echo 1 > f; git add f; gi commit -qm c1; git push -q origin main; cd ..
git clone -q up.git cl 2>/dev/null; cd cl
git remote set-url origin https://github.com/o/r.git
echo "## online start + main sync"
cd "$T/seed"; echo 2 >> f; gi commit -qam c2; git push -q origin main; cd "$T/cl"
expect "env sees github, online"      0 "mode=github .*online=yes" with_shim $W env
expect "start online"                 0 "worktree .*feat-42-csv"   with_shim $W start feat 42 csv
expect "local main fast-forwarded"    0 -  bash -c '[ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ] && grep -q 2 f'
expect "branch based on new main"     0 -  bash -c '[ "$(git rev-parse feat/42-csv~0)" = "$(git rev-parse origin/main)" ]'
expect "no tracking"                  0 -  bash -c '[ -z "$(git config --get branch.feat/42-csv.merge)" ]'

echo "## dirty main checkout: warn, still branch from origin/main"
cd "$T/seed"; echo 3 >> f; gi commit -qam c3; git push -q origin main; cd "$T/cl"
echo dirty >> f
expect "dirty -> warns, works"        0 "uncommitted changes"      with_shim $W start fix 43 hot
expect "local main left at c2"        0 -  bash -c '[ "$(git rev-parse main)" != "$(git rev-parse origin/main)" ]'
expect "fix branch at origin/main"    0 -  bash -c '[ "$(git rev-parse fix/43-hot)" = "$(git rev-parse origin/main)" ]'
git checkout -q -- f

echo "## main checkout on another branch"
git checkout -q -b scratch
cd "$T/seed"; echo 4 >> f; gi commit -qam c4; git push -q origin main; cd "$T/cl"
expect "on scratch -> warns, works"   0 "is on scratch"            with_shim $W start chore 44 tidy
git checkout -q main

echo "## resume (local CLI)"
expect "resume reuses worktree"       0 "worktree .*feat-42-csv on feat/42-csv" with_shim $W resume feat/42-csv
( cd .worktrees/feat-42-csv && echo w > w && git add w && gi commit -qm w && git push -q "$WF_BARE" feat/42-csv:feat/42-csv )
expect "ahead/behind reported"        0 "vs origin/feat/42-csv: ahead 0, behind 0" with_shim $W resume feat/42-csv
git worktree remove --force .worktrees/feat-42-csv
expect "recreates from local branch"  0 "worktree .*feat-42-csv"   with_shim $W resume feat/42-csv
git worktree remove --force .worktrees/feat-42-csv; git branch -q -D feat/42-csv
expect "creates from origin only"     0 "worktree .*feat-42-csv"   with_shim $W resume feat/42-csv
expect "tracks origin/<branch>"       0 "refs/heads/feat/42-csv"   git config --get branch.feat/42-csv.merge
expect "resume nonexistent"           1 "no such branch"           with_shim $W resume feat/99-nope
expect "resume invalid name"          1 "branch must look like"    with_shim $W resume --force
expect "start existing says resume"   1 "use resume"               with_shim $W start feat 42 csv

echo "## resume (cloud)"
cd "$T"; rm -rf cl2; git clone -q up.git cl2 2>/dev/null; cd cl2; git config user.email t@t; git config user.name t
expect "cloud resume from origin"     0 "^branch feat/42-csv"      env CLAUDE_CODE_REMOTE=true bash -c "$W resume feat/42-csv"
expect "cloud: tracking origin"       0 "refs/heads/feat/42-csv"   git config --get branch.feat/42-csv.merge
expect "cloud: on the branch"         0 "feat/42-csv"              git branch --show-current

echo "## resume (local-only)"
cd "$T"; rm -rf lo; git init -q -b main lo; cd lo; git config user.email t@t; git config user.name t
echo a > a; git add a; git commit -qm i; git branch feat/lo-only
expect "local-only resume"            0 "worktree .*feat-lo-only"  $W resume feat/lo-only
expect "local-only unknown branch"    1 "no such branch"           $W resume feat/zzz

echo "## resume offline (unreachable github remote)"
cd "$T"; rm -rf off; git clone -q up.git off 2>/dev/null; cd off; git config user.email t@t; git config user.name t
git remote set-url origin https://github.com/nonexistent-zz/none.git
expect "offline resume works, warns"  0 "could not reach origin" env GIT_TERMINAL_PROMPT=0 bash -c "$W resume feat/42-csv"

echo; echo "passed=$PASS failed=$FAIL"
