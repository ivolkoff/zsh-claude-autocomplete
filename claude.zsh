# claude.zsh — entry point for zsh-claude-completions.
#
# Source this from ~/.zshrc:
#     source /path/to/zsh-claude-completions/claude.zsh
#
# It puts the completion function on $fpath, makes sure compinit has run, and
# exposes the install directory so the _claude function can find its data file
# and generator regardless of how it was loaded.

# Resolve this file's directory (works when sourced).
typeset -g _CLAUDE_AC_DIR=${${(%):-%x}:A:h}

# Put the completion function (the `_claude` file) on fpath.
fpath=( $_CLAUDE_AC_DIR $fpath )

# Initialise compsys if the caller hasn't already (e.g. plain `source` install).
if ! whence compdef >/dev/null 2>&1; then
  autoload -Uz compinit && compinit
fi

# Ensure our function is registered even if compinit ran before fpath changed.
autoload -Uz _claude
compdef _claude claude 2>/dev/null
