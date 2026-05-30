## Why

The `claude` CLI has many subcommands, flags, model IDs, and reads user-specific
artifacts (slash commands, skills, sessions) from `~/.claude/`. Today users type
all of these by hand at the shell prompt, which is slow and error-prone — long
model IDs, exact session UUIDs, and rarely-used flags are easy to mistype. zsh
already provides a completion engine; this change adds a completion function so
`<TAB>` offers the right values in the right place.

This is shell-level completion (the zsh prompt), distinct from and complementary
to the interactive completion already built into the `claude` REPL.

## What Changes

- Add a zsh completion function (`_claude`) that completes `claude`'s
  **subcommands** (`agents`, `auth`, `doctor`, `install`, `mcp`, `plugin`,
  `project`, `setup-token`, `update`, ...) and **flags** (`--model`,
  `--continue`, `--resume`, `--print`, `--permission-mode`, `--effort`,
  `--dangerously-skip-permissions`, ...). The real CLI exposes ~50 flags and a
  dozen subcommands, so this surface is not hand-curated — see below.
- Complete **enumerated flag values** for flags whose `--help` declares a fixed
  choice set: `--permission-mode`, `--output-format`, `--input-format`,
  `--effort`.
- Complete **dynamic values** read from the environment:
  - model IDs and aliases (`opus`, `sonnet`, `haiku`, full IDs; overridable);
  - slash-command file names from user and project `commands/` dirs;
  - skill names from user and project `skills/` dirs;
  - session IDs for `--resume`, read from `~/.claude/projects/<cwd>/<uuid>.jsonl`;
  - file paths after a literal `@`.
- **Generate the static surface from `claude --help`** (top-level and each
  subcommand) into a version-pinned data file, instead of hand-maintaining it.
  A committed snapshot ships with the repo; the function auto-refreshes the data
  when the installed `claude --version` no longer matches the snapshot. This is
  what keeps completion correct across `claude` releases with no manual edits.
- Add an **entry point** (`claude.zsh`) plus install paths: manual `source`,
  `fpath` + `compinit`, and an Oh My Zsh plugin layout.
- Add **configuration** via environment variables
  (`CLAUDE_AUTOCOMPLETE_MODELS`, `*_COMMANDS_DIR`, `*_SKILLS_DIR`,
  `*_PROJECTS_DIR`, `*_NO_SESSIONS`) to override defaults.
- Session lookup and data reads must stay fast (target <50 ms); completion-time
  code never forks `claude` — it reads the cached data file.

## Capabilities

### New Capabilities
- `static-completion`: Completion of the `claude` CLI's fixed surface —
  subcommands, flags, flag/value placement, and enumerated flag values.
- `dynamic-completion`: Context-aware completion of values sourced at runtime —
  model IDs/aliases, slash-command names, skill names, `--resume` session IDs,
  and `@` file paths — with performance bounds.
- `completion-data`: How the static surface is generated from `claude --help`,
  cached as a version-pinned snapshot, and auto-refreshed when `claude` updates.
- `installation-and-config`: How the completion is loaded into a shell (source,
  fpath/compinit, Oh My Zsh) and the environment variables that override
  defaults.

### Modified Capabilities
<!-- None — greenfield project, no existing specs. -->

## Impact

- New files: `claude.zsh` (entry point), `_claude` (autoloaded completion
  function), `lib/` (dynamic-value helpers + generated `_claude_data.zsh`
  snapshot), `bin/claude-completion-gen` (the `--help` → data-file generator).
- New env vars consumed: `CLAUDE_AUTOCOMPLETE_*` (listed above).
- Reads (never writes) from `~/.claude/commands/`, `~/.claude/skills/`,
  `~/.claude/projects/`, and project-local `./.claude/` equivalents.
- Invokes `claude --help` / `claude --version` only at generation/refresh time,
  never on the completion hot path.
- Runtime dependency: zsh 5.0+ with `compinit`; `claude` on `$PATH`. No build
  step, no third-party libraries.
- Bash and fish are explicitly out of scope for this change.
