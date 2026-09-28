#!/usr/bin/env zsh
emulate -LR zsh
setopt errexit pipefail
cd -- ${0:A:h:h}
source ./jev-fzf.plugin.zsh
unset JEV_FZF_NO_RANK JEV_FZF_PROVIDER TEST_MODE
tmp=$(mktemp -d)
trap 'rm -f -- "$tmp/jev" "$tmp/state" "$tmp/calls"; rmdir -- "$tmp"' EXIT
cp tests/fixtures/jev "$tmp/jev"
chmod +x "$tmp/jev"
path=("$tmp" $path)
export TEST_STATE="$tmp/state" TEST_CALLS="$tmp/calls"
export TEST_RESPONSE='{"answers":{"result":{"type":"choice","probabilities":{"c0":0.2,"c1":0.8}}}}'
original=$'git status\0printf "hello\nworld"\n\0git status\0'
expected=$'  80%\tprintf "hello\nworld"\n\0  20%\tgit status\0'
actual=$(printf '%s' "$original" | _jev_fzf_rank 'hello')
[[ $actual == $expected ]] || { print -u2 'FAIL: ranking or exact command preservation'; exit 1; }
command jq -e '.query == "hello" and (.cwd | length > 0) and (keys == ["candidates", "cwd", "query", "recent_commands"])' "$TEST_STATE" >/dev/null

for TEST_RESPONSE in 'invalid' '{"answers":{"result":{"type":"choice","probabilities":{"c0":null,"c1":1}}}}' '{"answers":{"result":{"type":"choice","probabilities":{"c0":0.1,"c1":0.1}}}}' '{"answers":{"result":{"type":"choice","probabilities":{"c0":0.2,"unknown":0.8}}}}'; do
  actual=$(printf '%s' "$original" | _jev_fzf_rank '')
  [[ $actual == $'    —\tgit status\0    —\tprintf "hello\nworld"\n\0' ]] || exit 2
done
TEST_RESPONSE='{"answers":{"result":{"type":"choice","probabilities":{"c0":0.5,"c1":0.5}}}}'
actual=$(printf '%s\0' one two | _jev_fzf_rank '')
[[ $actual == $'  50%\tone\0  50%\ttwo\0' ]] || exit 3

# fzf searches command text only, and removing the label preserves literal tabs.
TEST_RESPONSE='{"answers":{"result":{"type":"choice","probabilities":{"c0":0.724,"c1":0.276}}}}'
literal=$'printf\t"literal"\n'
actual=$(printf '%s\0' "$literal" other | _jev_fzf_rank '')
[[ $actual == $'72.4%\tprintf\t"literal"\n\0'"27.6%"$'\tother\0' ]] || exit 11
selected=$(printf '%s' "$actual" | FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE='' command fzf --read0 --print0 --tiebreak=index --delimiter=$'\t' --nth=2.. --filter='^printf')
[[ ${${selected%$'\0'}#*$'\t'} == $literal ]] || exit 12
if printf '%s' "$actual" | FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE='' command fzf --read0 --delimiter=$'\t' --nth=2.. --filter=72.4 >/dev/null; then
  print -u2 'FAIL: probability column was searchable'; exit 13
fi

# Fixed shortlist: rank 50 entries while retaining older commands locally.
TEST_RESPONSE=$(jq -n '{answers:{result:{type:"choice",probabilities:([range(50) | {key:("c"+tostring),value:0.02}] | from_entries)}}}')
original=$(printf 'command-%s\0' {1..51})
actual=$(printf '%s' "$original" | _jev_fzf_rank '')
expected=$(printf '   2%%\tcommand-%s\0' {1..50}; printf '    —\tcommand-51\0')
[[ $actual == $expected ]] || exit 4
command jq -e '(.candidates | length) == 50 and (.recent_commands | length) == 5' "$TEST_STATE" >/dev/null

export TEST_MODE=fail
actual=$(printf '%s\0' one two | _jev_fzf_rank '')
[[ $actual == $'    —\tone\0    —\ttwo\0' ]] || exit 5
export TEST_MODE=slow
zmodload zsh/datetime
start=$EPOCHREALTIME
actual=$(printf '%s\0' one two | _jev_fzf_rank '')
(( EPOCHREALTIME - start < 4 )) || exit 6
[[ $actual == $'    —\tone\0    —\ttwo\0' ]] || exit 7
before=$(wc -c < "$TEST_CALLS")
actual=$(printf '%s\0' one one | _jev_fzf_rank '')
[[ $actual == $'    —\tone\0' ]] || exit 8
JEV_FZF_NO_RANK=1
actual=$(printf '%s\0' one two one | _jev_fzf_rank '')
[[ $actual == $'    —\tone\0    —\ttwo\0' ]] || exit 9
[[ $(wc -c < "$TEST_CALLS") == $before ]] || exit 10
print 'PASS: ranking, fixed shortlist, exact history, response validation, fallback and timeout'
