## ADDED Requirements

### Requirement: Subcommand completion

The completion function SHALL offer the `claude` CLI's subcommands as candidates
when the user requests completion in the first non-flag argument position.

#### Scenario: Listing subcommands at top level

- **WHEN** the user types `claude ` and presses `<TAB>`
- **THEN** the completion offers the known subcommands (including `mcp`,
  `plugin`, `agents`, `update`, `doctor`)

#### Scenario: Prefix-filtering subcommands

- **WHEN** the user types `claude pl` and presses `<TAB>`
- **THEN** only subcommands whose name begins with `pl` (e.g. `plugin`) are
  offered

#### Scenario: No subcommand offered after one is chosen

- **WHEN** the user has already typed a subcommand (e.g. `claude config `) and
  presses `<TAB>`
- **THEN** the top-level subcommand list is NOT repeated as candidates

### Requirement: Flag completion

The completion function SHALL offer the `claude` CLI's flags as candidates when
the current word begins with `-`, and each flag SHALL carry a short description.

#### Scenario: Listing flags

- **WHEN** the user types `claude --` and presses `<TAB>`
- **THEN** the completion offers the known flags (including `--model`,
  `--continue`, `--resume`, `--print`, `--dangerously-skip-permissions`)

#### Scenario: Prefix-filtering flags

- **WHEN** the user types `claude --m` and presses `<TAB>`
- **THEN** `--model` is offered

#### Scenario: A flag is not offered twice

- **WHEN** a flag that takes no repetition has already been supplied on the
  command line and the user requests completion again
- **THEN** that flag is excluded from the candidate list

### Requirement: Flag-value placement

The completion function SHALL complete a flag's value — rather than offering
subcommands or other flags — when the word being completed follows a flag that
expects a value.

#### Scenario: Completing the value of a value-taking flag

- **WHEN** the user types `claude --model ` and presses `<TAB>`
- **THEN** completion candidates are model IDs (the value for `--model`), not
  subcommands or unrelated flags

#### Scenario: Boolean flag takes no value

- **WHEN** the user types `claude --continue ` and presses `<TAB>`
- **THEN** completion does NOT attempt to complete a value for `--continue`,
  and normal argument/flag completion resumes

### Requirement: Enumerated flag-value completion

The completion function SHALL offer exactly the declared choices as candidates
for any flag whose value is restricted to a fixed choice set by the CLI.

#### Scenario: Completing --permission-mode choices

- **WHEN** the user types `claude --permission-mode ` and presses `<TAB>`
- **THEN** the completion offers `acceptEdits`, `auto`, `bypassPermissions`,
  `default`, `dontAsk`, and `plan`

#### Scenario: Completing --output-format choices

- **WHEN** the user types `claude --output-format ` and presses `<TAB>`
- **THEN** the completion offers `text`, `json`, and `stream-json`

#### Scenario: Completing --effort choices

- **WHEN** the user types `claude --effort ` and presses `<TAB>`
- **THEN** the completion offers `low`, `medium`, `high`, `xhigh`, and `max`
