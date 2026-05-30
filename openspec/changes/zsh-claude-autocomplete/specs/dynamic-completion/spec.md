## ADDED Requirements

### Requirement: Model ID completion

The completion function SHALL offer model IDs and aliases as candidates for the
`--model` flag value. The candidate set SHALL default to a built-in list that
includes both short aliases and full IDs, and SHALL be overridable via the
`CLAUDE_AUTOCOMPLETE_MODELS` environment variable.

#### Scenario: Default model list includes aliases and full IDs

- **WHEN** `CLAUDE_AUTOCOMPLETE_MODELS` is unset and the user completes a
  `--model` value
- **THEN** the built-in candidates include the aliases `opus`, `sonnet`,
  `haiku` and full IDs (including `claude-opus-4-8`, `claude-sonnet-4-6`)

#### Scenario: Overridden model list

- **WHEN** `CLAUDE_AUTOCOMPLETE_MODELS` is set to a space-separated list of IDs
- **THEN** exactly those values are offered as `--model` candidates, replacing
  the built-in list

### Requirement: Slash-command completion

The completion function SHALL offer slash-command file names as candidates,
read from both the user commands directory and the project-local commands
directory. The user directory SHALL default to `~/.claude/commands/` and be
overridable via `CLAUDE_AUTOCOMPLETE_COMMANDS_DIR`.

#### Scenario: Completing from the user commands directory

- **WHEN** files exist under `~/.claude/commands/` and the user requests
  slash-command completion
- **THEN** their base names (without the file extension) are offered

#### Scenario: Project commands are included

- **WHEN** a project-local `./.claude/commands/` directory exists with command
  files
- **THEN** those names are offered in addition to the user-directory names

#### Scenario: Missing directory is not an error

- **WHEN** the commands directory does not exist
- **THEN** no candidates are offered and no error is printed

### Requirement: Skill completion

The completion function SHALL offer skill names as candidates, read from the
user skills directory (default `~/.claude/skills/`, overridable via
`CLAUDE_AUTOCOMPLETE_SKILLS_DIR`) and the project-local skills directory.

#### Scenario: Completing skill names

- **WHEN** skill directories exist under `~/.claude/skills/` and the user
  requests skill completion
- **THEN** the skill names are offered

#### Scenario: Missing skills directory is not an error

- **WHEN** the skills directory does not exist
- **THEN** no candidates are offered and no error is printed

### Requirement: Session ID completion

The completion function SHALL offer session IDs as candidates for the
`--resume` flag value. Session files are stored at
`<projects-dir>/<encoded-cwd>/<session-uuid>.jsonl` (default projects dir
`~/.claude/projects/`, overridable via `CLAUDE_AUTOCOMPLETE_PROJECTS_DIR`); the
session ID is the file's base name without the `.jsonl` extension. Session
lookup SHALL complete within 50 ms on a typical projects directory so that
completion does not stall the prompt.

#### Scenario: Completing session IDs for --resume

- **WHEN** the user types `claude --resume ` and presses `<TAB>`
- **THEN** recent session IDs (the `.jsonl` base names found one level below the
  projects directory) are offered, most recently modified first

#### Scenario: Sessions disabled

- **WHEN** `CLAUDE_AUTOCOMPLETE_NO_SESSIONS=1` is set and the user completes a
  `--resume` value
- **THEN** no session IDs are looked up or offered

#### Scenario: Lookup performance bound

- **WHEN** session ID completion runs against a typical projects directory
- **THEN** it returns within 50 ms

### Requirement: File-path completion after @

When the current word begins with a literal `@`, the completion function SHALL
complete filesystem paths for the portion following the `@`.

#### Scenario: Completing a path after @

- **WHEN** the user types `claude @src/` and presses `<TAB>`
- **THEN** filesystem entries under `src/` are offered, completing the path
  after the `@`
