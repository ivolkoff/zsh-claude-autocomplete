## ADDED Requirements

### Requirement: Static surface generated from CLI help

The project SHALL derive its static completion surface (subcommands, flags, flag
value-arity, flag descriptions, and enumerated flag choices) by parsing the
output of `claude --help` and `claude <subcommand> --help`, rather than
hand-maintaining the lists. A generator script SHALL produce a data file that
the completion function reads.

#### Scenario: Generator builds the data file

- **WHEN** the generator is run against an installed `claude`
- **THEN** it writes a data file containing the subcommand list, the flag list
  with descriptions, the value-arity of each flag, and the choice set for every
  flag whose help declares one

#### Scenario: Descriptions and choices are captured despite line wrapping

- **WHEN** a flag's help description (or its `choices:` list) wraps across
  multiple lines in `claude --help`
- **THEN** the generator joins the wrapped lines for that flag before parsing,
  so the full description and complete choice set are captured

### Requirement: Version-pinned snapshot ships with the repo

The repository SHALL include a committed, generated data-file snapshot together
with the `claude` version it was generated from, so completion works
immediately after install with no generation step and without invoking `claude`
on the completion hot path.

#### Scenario: Completion works offline from the snapshot

- **WHEN** the completion runs and `claude` cannot be invoked (offline, or
  `claude` momentarily unavailable)
- **THEN** completion still offers the subcommands, flags, and choices from the
  committed snapshot

#### Scenario: Completion does not fork claude per keystroke

- **WHEN** the user requests completion of subcommands or flags
- **THEN** the completion reads the cached data file and does NOT run
  `claude --help` or `claude --version` as part of serving candidates

### Requirement: Automatic refresh on CLI version change

The data file SHALL record the `claude` version it was generated from. When the
installed `claude --version` differs from the recorded version, the project
SHALL refresh the data file (regenerate, or surface a one-time hint to run the
generator) so the completion tracks the installed CLI without manual edits.

#### Scenario: CLI upgrade triggers a refresh

- **WHEN** `claude` is upgraded so that `claude --version` no longer matches the
  version recorded in the data file
- **THEN** the data file is regenerated (or the user is prompted once to
  regenerate) so new subcommands, flags, and choices become available

#### Scenario: Matching version does no work

- **WHEN** the installed `claude --version` equals the recorded version
- **THEN** no regeneration occurs and completion serves directly from the cached
  data file
