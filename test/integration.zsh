#!/usr/bin/env zsh
# Live completion smoke test using zpty: drive a real interactive zsh, source
# the plugin, and capture what `claude <TAB>` actually offers. Complements
# test/run.sh (pure-logic unit tests) by exercising the real _arguments wiring.
#
# Reads block until an expected marker appears; every marker is the output of a
# `print` builtin (guaranteed to be emitted) or the shell prompt, so the reads
# always terminate. Writes a summary to test/_integration.txt. Exits 0 on pass,
# 1 on failure, 2 if a pty cannot be allocated / driven (skipped).

emulate -L zsh

typeset ROOT=${0:A:h:h}
typeset OUT=$ROOT/test/_integration.txt
typeset TMP=$(mktemp -d)
typeset -i PASS=0 FAIL=0
typeset -a FAILED
ok()  { (( ++PASS )); return 0 }
bad() { (( ++FAIL )); FAILED+=("$1"); return 0 }

zmodload zsh/zpty 2>/dev/null || { print "SKIP: zsh/zpty unavailable" | tee $OUT; exit 2 }

# Wall-clock watchdog: some sandboxed/CI ptys don't echo completion output and a
# blocking read could otherwise stall. SIGALRM turns that into a clean SKIP.
TRAPALRM() { print "SKIP: pty interaction timed out" | tee $OUT; exit 2 }
{ sleep 45; kill -ALRM $$ 2>/dev/null } &!
typeset WATCHDOG=$!
trap 'kill $WATCHDOG 2>/dev/null; zpty -d cc 2>/dev/null; rm -rf $TMP' EXIT

if ! zpty -b cc zsh -f; then
  print "SKIP: cannot allocate pty" | tee $OUT; exit 2
fi

# Blocking read of the pty until $1 appears (or EOF / budget). Returns 0 if seen.
read_until() {
  local needle=$1 x
  REPLY=""
  integer n=0
  while (( n++ < 5000 )); do
    zpty -r cc x 2>/dev/null || break
    REPLY+=$x
    [[ $REPLY == *$needle* ]] && return 0
  done
  [[ $REPLY == *$needle* ]]
}

# Set up the inner interactive shell. Commands are processed in order, so a
# READY barrier (a plain builtin that always prints) guarantees claude.zsh has
# been sourced before we trigger any completion.
zpty -w cc "PS1=@@@"
zpty -w cc "autoload -Uz compinit && compinit -u -d $TMP/zcd"
zpty -w cc "source $ROOT/claude.zsh"
zpty -w cc "claude(){ : }"
zpty -w cc "print __READY__"
if ! read_until __READY__; then
  print "SKIP: shell did not become ready in pty" | tee $OUT; exit 2
fi

# Capture completion output: send "<text>\t" (the list/insertion is emitted to
# the pty synchronously), ^U to discard the line, then a sentinel `print` whose
# output both terminates the read and proves we got back to a usable prompt. The
# completion bytes precede the sentinel in the stream.
integer _sent=0
capture() {
  local text=$1 sentinel="__SENT$(( ++_sent ))__"
  zpty -w -n cc "$text"$'\t'
  zpty -w -n cc $'\C-u'
  zpty -w cc "print $sentinel"
  read_until $sentinel
}

capture 'claude '
[[ $REPLY == *mcp* ]]    && ok || bad "subcommand list shows mcp"
[[ $REPLY == *plugin* ]] && ok || bad "subcommand list shows plugin"

capture 'claude --mod'
[[ $REPLY == *model* ]] && ok || bad "flag --mod completes to --model"

capture 'claude --permission-mode '
[[ $REPLY == *acceptEdits* ]] && ok || bad "--permission-mode offers acceptEdits"

{
  print -r -- "PASS=$PASS FAIL=$FAIL"
  (( FAIL )) && { print -r -- "FAILED:"; print -rl -- $FAILED }
} | tee $OUT

(( FAIL == 0 ))
