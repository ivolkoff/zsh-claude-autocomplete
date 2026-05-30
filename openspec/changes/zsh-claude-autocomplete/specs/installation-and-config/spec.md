## ADDED Requirements

### Requirement: Loading via source entry point

The project SHALL provide an entry-point script (`claude.zsh`) that, when
sourced from `~/.zshrc`, registers the `_claude` completion function so that
`claude <TAB>` works in a new shell.

#### Scenario: Sourcing the entry point enables completion

- **WHEN** a user adds `source <repo>/claude.zsh` to `~/.zshrc` and starts a
  new zsh session
- **THEN** `claude <TAB>` offers completions

#### Scenario: Function autoloads via fpath + compinit

- **WHEN** the repo directory is on `$fpath` and `compinit` has run
- **THEN** the `_claude` completion function is autoloaded without an explicit
  `source` of the function file

### Requirement: Oh My Zsh plugin layout

The project SHALL be installable as an Oh My Zsh plugin by cloning into the
custom plugins directory and adding `zsh-claude-completions` to the `plugins`
array.

#### Scenario: Loading as an Oh My Zsh plugin

- **WHEN** the repo is cloned to
  `${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-claude-completions` and
  `zsh-claude-completions` is added to the `plugins=(...)` array
- **THEN** completion is enabled after reloading the shell

### Requirement: Configuration via environment variables

The completion behavior SHALL be configurable through environment variables
exported before the entry point is sourced. Each variable SHALL fall back to a
documented default when unset.

#### Scenario: Defaults apply when no variables are set

- **WHEN** none of the `CLAUDE_AUTOCOMPLETE_*` variables are exported
- **THEN** the completion uses the built-in model list and the
  `~/.claude/commands`, `~/.claude/skills`, and `~/.claude/projects` directories

#### Scenario: Directory overrides are honored

- **WHEN** `CLAUDE_AUTOCOMPLETE_COMMANDS_DIR`, `CLAUDE_AUTOCOMPLETE_SKILLS_DIR`,
  or `CLAUDE_AUTOCOMPLETE_PROJECTS_DIR` is exported before sourcing
- **THEN** completion reads from the specified directory instead of the default

#### Scenario: Disabling session completion

- **WHEN** `CLAUDE_AUTOCOMPLETE_NO_SESSIONS=1` is exported
- **THEN** session ID completion is skipped entirely

### Requirement: Runtime prerequisites

The completion SHALL operate with no build step and no third-party
dependencies, requiring only zsh 5.0+ with `compinit` available and the
`claude` CLI on `$PATH`.

#### Scenario: Works on a clean zsh 5.0+ environment

- **WHEN** the user has zsh 5.0 or newer with `compinit` and `claude` on
  `$PATH`
- **THEN** the completion loads and functions without installing any additional
  packages
