# lib/_claude_sources.zsh — pure candidate sources for the claude completion.
#
# Each function prints one candidate per line and has NO dependency on the
# completion runtime (no _describe/compadd). This keeps them unit-testable: set
# the relevant CLAUDE_AUTOCOMPLETE_* env vars, call the function, assert on
# stdout. The _claude completion wraps these with _describe.

__claude_list_models() {
  emulate -L zsh
  if [[ -n ${CLAUDE_AUTOCOMPLETE_MODELS-} ]]; then
    print -l -- ${(s: :)CLAUDE_AUTOCOMPLETE_MODELS}
  else
    print -l -- \
      opus sonnet haiku \
      claude-opus-4-8 claude-sonnet-4-6 claude-haiku-4-5
  fi
}

__claude_list_commands() {
  emulate -L zsh
  setopt extended_glob
  local userdir=${CLAUDE_AUTOCOMPLETE_COMMANDS_DIR:-$HOME/.claude/commands}
  local d
  local -a out
  for d in $userdir ./.claude/commands; do
    [[ -d $d ]] || continue
    out+=( $d/*(N.:t:r) )
  done
  (( ${#out} )) && print -l -- ${(u)out}
  return 0
}

__claude_list_skills() {
  emulate -L zsh
  setopt extended_glob
  local userdir=${CLAUDE_AUTOCOMPLETE_SKILLS_DIR:-$HOME/.claude/skills}
  local d
  local -a out
  for d in $userdir ./.claude/skills; do
    [[ -d $d ]] || continue
    out+=( $d/*(N/:t) )
  done
  (( ${#out} )) && print -l -- ${(u)out}
  return 0
}

# Best-effort refresh of the data snapshot when the installed `claude` version no
# longer matches it. Runs at most once per shell and never forks `claude` on the
# completion hot path beyond a single `--version` check. $1 = install dir.
__claude_refresh_if_stale() {
  emulate -L zsh
  local cl_dir=$1
  [[ -n ${_CLAUDE_AC_NO_REFRESH-} ]] && return 0
  (( ${+_claude_refresh_checked} )) && return 0
  typeset -g _claude_refresh_checked=1
  command -v claude >/dev/null 2>&1 || return 0
  local live=$(command claude --version 2>/dev/null)
  live=${live//[^0-9.]/ }
  local -a parts=( ${(z)live} )
  live=${parts[1]}
  [[ -z $live || $live == ${_claude_data_version-} ]] && return 0
  [[ -r $cl_dir/bin/claude-completion-gen ]] || return 0
  local cache=${XDG_CACHE_HOME:-$HOME/.cache}/zsh-claude-completions
  mkdir -p $cache 2>/dev/null || return 0
  if zsh $cl_dir/bin/claude-completion-gen --out $cache/_claude_data.zsh >/dev/null 2>&1; then
    source $cache/_claude_data.zsh
  fi
  return 0
}

# Build the _arguments option-spec array from the generated data tables into the
# global `_claude_specs`. Kept here (not inline in _claude) so it is unit-testable
# without a completion context. Reads _claude_flag_* / _claude_choices globals.
__claude_build_specs() {
  emulate -L zsh
  typeset -ga _claude_specs=()
  typeset -ga _claude_flag_describe=()
  local f short act desc
  for f in $_claude_flag_names; do
    # Neutralize chars that would break an _arguments `optname[desc]:msg:action`
    # spec. Square brackets delimit the description; converting any in the help
    # text to parens keeps the [desc] field balanced, so colons inside it stay
    # literal instead of being parsed as message/action separators. More robust
    # than backslash-escaping, which can leave the field unbalanced and trigger
    # "comparguments: too many arguments".
    desc=${_claude_flag_desc[$f]}
    desc=${desc//\[/(}
    desc=${desc//\]/)}
    # name:desc rows for the fallback shown when a value slot is offered another
    # flag (see __claude_flag_fallback). _describe splits on the first ':'.
    _claude_flag_describe+=( "${f}:${desc}" )
    short=${_claude_flag_short[$f]-}
    # Every value-taking flag routes its value through a `->state` so the
    # completion function can, when the word being typed looks like another flag
    # (starts with '-'), fall back to offering the flag list instead of dead-
    # ending on the value completer. Boolean flags carry no action.
    if [[ ${_claude_flag_arg[$f]} == 1 ]]; then
      if [[ -n ${_claude_choices[$f]-} ]]; then
        act=':value:->choice'
      elif [[ $f == --model || $f == --fallback-model ]]; then
        act=':model:->models'
      elif [[ $f == --resume ]]; then
        act=':session:->sessions'
      elif [[ $f == (--add-dir|--plugin-dir) ]]; then
        act=':dir:->dirs'
      elif [[ $f == (--settings|--file|--mcp-config|--debug-file|--system-prompt) ]]; then
        act=':file:->files'
      else
        act=':value:->value'
      fi
    else
      act=''
    fi
    if [[ -n $short ]]; then
      _claude_specs+=( "(${short} ${f})"{$short,$f}"[${desc}]${act}" )
    else
      _claude_specs+=( "${f}[${desc}]${act}" )
    fi
  done
}

# Offer the full flag list as completion candidates. Used as a fallback when the
# user is typing another flag (word starts with '-') while a value slot is being
# completed, so completion never dead-ends "no matter how deep" into the command.
__claude_flag_fallback() {
  (( ${#_claude_flag_describe} )) || __claude_build_specs
  _describe -t options 'option' _claude_flag_describe
}

__claude_list_sessions() {
  emulate -L zsh
  setopt extended_glob
  [[ -n ${CLAUDE_AUTOCOMPLETE_NO_SESSIONS-} ]] && return 0
  local pdir=${CLAUDE_AUTOCOMPLETE_PROJECTS_DIR:-$HOME/.claude/projects}
  [[ -d $pdir ]] || return 0
  # Sessions live one level deep: <projects>/<encoded-cwd>/<uuid>.jsonl
  # Newest first (om), capped, base name without .jsonl.
  local -a files=( $pdir/*/*.jsonl(.omN[1,40]:t:r) )
  (( ${#files} )) && print -l -- $files
  return 0
}
