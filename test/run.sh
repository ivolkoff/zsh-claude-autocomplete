#!/usr/bin/env zsh
# Test suite for zsh-claude-completions.
# Run: ./test/run.sh   (or: zsh test/run.sh)
# Exits non-zero if any check fails. A summary is also written to
# test/_results.txt so results survive output-mangling proxies.

emulate -L zsh
setopt extended_glob

typeset ROOT=${0:A:h:h}
typeset RESULTS=$ROOT/test/_results.txt
typeset -i PASS=0 FAIL=0
typeset -a FAILED

ok()   { (( ++PASS )); return 0; }
bad()  { (( ++FAIL )); FAILED+=( "$1" ); return 0; }

# assert "$2" (haystack) contains "$3" (needle); label "$1"
has()    { [[ $2 == *$3* ]] && ok || bad "$1 (missing: $3)"; }
hasnt()  { [[ $2 != *$3* ]] && ok || bad "$1 (should not contain: $3)"; }
eq()     { [[ $2 == $3 ]] && ok || bad "$1 (got [$2] want [$3])"; }
# literal (non-glob) substring assertions — for needles with ()[]: chars
lhas()   { [[ ${2//"$3"/} != "$2" ]] && ok || bad "$1 (missing: $3)"; }
lhasnt() { [[ ${2//"$3"/} == "$2" ]] && ok || bad "$1 (should not contain: $3)"; }

typeset GEN=$ROOT/bin/claude-completion-gen
typeset TMP=$(mktemp -d)
trap 'rm -rf $TMP' EXIT

# =========================================================================
# 1. Generator — real fixture (claude --help v2.1.156)
# =========================================================================
zsh $GEN --help-file $ROOT/test/fixtures/claude-help.txt \
         --version-string 2.1.156 --out $TMP/data.zsh >/dev/null 2>&1
typeset realdata=$(<$TMP/data.zsh)

has   "1.1 version recorded"          "$realdata" "_claude_data_version='2.1.156'"
has   "1.2 subcommand mcp"            "$realdata" "'mcp:"
has   "1.3 subcommand plugin"         "$realdata" "'plugin:"
has   "1.4 subcommand update"         "$realdata" "'update:"
has   "1.5 subcommand ultrareview"    "$realdata" "'ultrareview:"
hasnt "1.6 no bogus config subcmd"    "$realdata" "'config:"
has   "1.7 flag --model"              "$realdata" "'--model'"
has   "1.8 flag --resume"             "$realdata" "'--resume'"
has   "1.9 flag --continue"           "$realdata" "'--continue'"
has   "1.10 short -c for --continue"  "$realdata" "'--continue' '-c'"
has   "1.11 short -r for --resume"    "$realdata" "'--resume' '-r'"
has   "1.12 choices permission-mode"  "$realdata" "'--permission-mode' 'acceptEdits auto bypassPermissions default dontAsk plan'"
has   "1.13 choices output-format"    "$realdata" "'--output-format' 'text json stream-json'"
has   "1.14 choices input-format"     "$realdata" "'--input-format' 'text stream-json'"
has   "1.15 choices effort (override)" "$realdata" "'--effort' 'low medium high xhigh max'"
hasnt "1.16 descriptions squeezed"    "$realdata" "tool  access"

source $TMP/data.zsh
eq "1.17 --model takes value"   "${_claude_flag_arg[--model]}"    "1"
eq "1.18 --continue is boolean" "${_claude_flag_arg[--continue]}" "0"
eq "1.19 --resume takes value"  "${_claude_flag_arg[--resume]}"   "1"

# =========================================================================
# 2. Generator — wrapped fixture (dewrap + inline choices + aliases)
# =========================================================================
zsh $GEN --help-file $ROOT/test/fixtures/wrapped-help.txt \
         --version-string 9.9.9 --out $TMP/wrap.zsh >/dev/null 2>&1
typeset wrapdata=$(<$TMP/wrap.zsh)

has "2.1 wrapped flag --foo"          "$wrapdata" "'--foo'"
has "2.2 dewrapped choices for --foo" "$wrapdata" "'--foo' 'aa bb cc'"
has "2.3 boolean --bar short -b"      "$wrapdata" "'--bar' '-b'"
has "2.4 subcommand doit"             "$wrapdata" "'doit:"
has "2.5 aliased subcommand primary"  "$wrapdata" "'combo:"

# A flag with two long forms ("--baz, --baz-alias") is stored under the last
# (more idiomatic kebab) long form.
unset _claude_flag_arg; typeset -gA _claude_flag_arg
source $TMP/wrap.zsh
eq "2.6 two-long flag stored as last long" "${_claude_flag_arg[--baz-alias]}" "1"
eq "2.7 --bar boolean"                     "${_claude_flag_arg[--bar]}" "0"

# =========================================================================
# 3. Dynamic sources — models
# =========================================================================
source $ROOT/lib/_claude_sources.zsh

typeset out
unset CLAUDE_AUTOCOMPLETE_MODELS
out=$(__claude_list_models)
has "3.1 default models include opus alias" "$out" "opus"
has "3.2 default models include full id"    "$out" "claude-opus-4-8"
CLAUDE_AUTOCOMPLETE_MODELS="m-one m-two"
out=$(__claude_list_models)
has   "3.3 override includes m-one" "$out" "m-one"
hasnt "3.4 override drops default"  "$out" "claude-opus-4-8"
unset CLAUDE_AUTOCOMPLETE_MODELS

# =========================================================================
# 4. Dynamic sources — commands & skills (user + project dirs, missing dir)
# =========================================================================
mkdir -p $TMP/home/commands $TMP/home/skills
print "x" > $TMP/home/commands/deploy.md
print "x" > $TMP/home/commands/review.md
mkdir -p $TMP/home/skills/debugger $TMP/home/skills/planner

CLAUDE_AUTOCOMPLETE_COMMANDS_DIR=$TMP/home/commands
CLAUDE_AUTOCOMPLETE_SKILLS_DIR=$TMP/home/skills
out=$(__claude_list_commands)
has   "4.1 command deploy (no ext)" "$out" "deploy"
has   "4.2 command review"          "$out" "review"
hasnt "4.3 command has no .md"      "$out" ".md"
out=$(__claude_list_skills)
has "4.4 skill debugger" "$out" "debugger"
has "4.5 skill planner"  "$out" "planner"

mkdir -p $TMP/proj/.claude/commands
print "x" > $TMP/proj/.claude/commands/projcmd.md
( cd $TMP/proj && __claude_list_commands ) > $TMP/projout.txt
has "4.6 project-local command" "$(<$TMP/projout.txt)" "projcmd"

CLAUDE_AUTOCOMPLETE_COMMANDS_DIR=$TMP/does-not-exist
out=$(__claude_list_commands 2>$TMP/err.txt); typeset rc=$?
eq "4.7 missing dir rc=0"      "$rc" "0"
eq "4.8 missing dir no stderr" "$(<$TMP/err.txt)" ""
eq "4.9 missing dir empty out" "$out" ""
unset CLAUDE_AUTOCOMPLETE_COMMANDS_DIR CLAUDE_AUTOCOMPLETE_SKILLS_DIR

# =========================================================================
# 5. Dynamic sources — sessions (nested glob, NO_SESSIONS, override)
# =========================================================================
mkdir -p $TMP/projects/-Users-x-proj $TMP/projects/-Users-y-other
print "x" > $TMP/projects/-Users-x-proj/aaaaaaaa-1111.jsonl
print "x" > $TMP/projects/-Users-y-other/bbbbbbbb-2222.jsonl
CLAUDE_AUTOCOMPLETE_PROJECTS_DIR=$TMP/projects
out=$(__claude_list_sessions)
has   "5.1 session id from nested glob" "$out" "aaaaaaaa-1111"
has   "5.2 second session id"           "$out" "bbbbbbbb-2222"
hasnt "5.3 no .jsonl suffix"            "$out" ".jsonl"
CLAUDE_AUTOCOMPLETE_NO_SESSIONS=1
out=$(__claude_list_sessions)
eq "5.4 NO_SESSIONS disables" "$out" ""
unset CLAUDE_AUTOCOMPLETE_NO_SESSIONS
unset CLAUDE_AUTOCOMPLETE_PROJECTS_DIR

# =========================================================================
# 6. Shipped snapshot sanity (data file used by the real completion)
# =========================================================================
unset _claude_data_version
source $ROOT/lib/_claude_data.zsh
eq "6.1 shipped snapshot version" "$_claude_data_version" "2.1.156"
(( ${#_claude_flag_names} >= 40 ))  && ok || bad "6.2 expected >=40 flags, got ${#_claude_flag_names}"
(( ${#_claude_subcommands} >= 10 )) && ok || bad "6.3 expected >=10 subcommands, got ${#_claude_subcommands}"

# =========================================================================
# 7. Completion function loads & is syntactically valid
# =========================================================================
if zsh -n $ROOT/_claude 2>$TMP/cl_err.txt; then ok; else bad "7.1 _claude syntax: $(<$TMP/cl_err.txt)"; fi
if zsh -n $ROOT/claude.zsh 2>$TMP/cz_err.txt; then ok; else bad "7.2 claude.zsh syntax: $(<$TMP/cz_err.txt)"; fi

# =========================================================================
# 8. _arguments spec building (the wiring fed to _arguments) — no pty needed
# =========================================================================
__claude_build_specs
typeset specs=${(j:|:)_claude_specs}
lhas "8.1 --model present"               "$specs" "--model"
lhas "8.2 --model routes to models"      "$specs" ":model:->models"
lhas "8.3 --resume routes to sessions"   "$specs" ":session:->sessions"
lhas "8.4 --permission-mode routes to choice" "$specs" ":value:->choice"
lhas "8.5 choice values kept in data"    "${_claude_choices[--permission-mode]}" "acceptEdits auto bypassPermissions default dontAsk plan"
lhas "8.6 --continue carries short -c"   "$specs" "(-c --continue)"
lhas "8.7 -r alias for --resume"         "$specs" "(-r --resume)"
# boolean flag has no value action (no ':' after its ']')
typeset pspec=${_claude_specs[(r)--print\[*]}
lhasnt "8.8 --print boolean has no action" "$pspec" "]:"
# a value flag's spec ends with an action introduced by ':'
typeset mspec=${_claude_specs[(r)*--model\[*]}
lhas "8.9 --model spec has an action"     "$mspec" "]:"
# Every spec must have exactly one '[' and one ']' (the [desc] delimiters). A
# description that leaked a bracket would create extra ':'-separated fields and
# make _arguments abort with "comparguments: too many arguments".
typeset -i _badbr=0
typeset _o _c sp
for sp in $_claude_specs; do
  _o=${sp//[^\[]/}; _c=${sp//[^\]]/}
  [[ ${#_o} -ne 1 || ${#_c} -ne 1 ]] && (( _badbr++ ))
done
eq "8.10 all specs have one balanced [desc]" "$_badbr" "0"
# No choice list may contain a ':' (commander metadata like preset:true must be
# stripped — a ':' in a (choices) action also corrupts the spec).
typeset -i _badch=0
typeset _k
for _k in ${(k)_claude_choices}; do
  [[ ${_claude_choices[$_k]} == *:* ]] && (( _badch++ ))
done
eq    "8.11 no choice list contains a colon"        "$_badch" "0"
lhasnt "8.12 prompt-suggestions dropped preset:true" "${_claude_choices[--prompt-suggestions]}" "preset"

# Value-flag dead-end fix: every value-taking flag routes to a ->state, and the
# fallback flag list is populated so a value slot can offer flags when the user
# types another '-'.
lhas "8.13 --debug-file routes to files state" "$specs" ":file:->files"
lhas "8.14 value flag routes to value state"   "$specs" ":value:->value"
typeset fdesc=${(j:|:)_claude_flag_describe}
lhas "8.15 fallback list has --debug-file" "$fdesc" "--debug-file:"
lhas "8.16 fallback list has --resume"     "$fdesc" "--resume:"
(( ${#_claude_flag_describe} == ${#_claude_flag_names} )) && ok \
  || bad "8.17 fallback list covers every flag (got ${#_claude_flag_describe}/${#_claude_flag_names})"

# =========================================================================
# Summary
# =========================================================================
{
  print -r -- "PASS=$PASS FAIL=$FAIL"
  (( FAIL )) && { print -r -- "FAILED:"; print -rl -- $FAILED }
} | tee $RESULTS

(( FAIL == 0 ))
