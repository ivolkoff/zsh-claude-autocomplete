## Context

zsh ships a mature programmable completion system (`compsys`). A completion for
a command `claude` is provided by an autoloadable function file named `_claude`
placed on `$fpath`, tagged with `#compdef claude` on its first line. After
`compinit` runs, zsh autoloads it on the first `claude <TAB>`.

The `claude` CLI exposes a fixed surface (subcommands, flags) plus values that
only exist at runtime in the user's environment (model IDs, slash commands,
skills, session IDs, `@` paths). The static surface can be hard-coded and
maintained as the CLI evolves; the dynamic surface must be read from `~/.claude`
on each completion request. The hard constraint from the proposal and README is
that this read stays fast (<50 ms) so the prompt never visibly stalls.

This is greenfield — no existing code, only the README describing intended
behavior. No build step, no dependencies beyond zsh and the `claude` binary.

## Goals / Non-Goals

**Goals:**
- A single autoloaded `_claude` function that drives all completion contexts.
- Context-correct completion: subcommand position vs flag vs flag-value vs `@`.
- Dynamic value sources read live from `~/.claude`, overridable by env vars.
- Session lookup that meets the <50 ms budget using zsh-native globbing (no
  external process spawns on the hot path).
- Multiple install methods (source, fpath+compinit, Oh My Zsh) from the same
  files.

**Non-Goals:**
- bash / fish completion (future work; out of scope here).
- Replacing the interactive REPL completion inside `claude`.
- Parsing `claude --help` on the **completion hot path** (every `<TAB>`) — too
  slow. Help is parsed only at generation/refresh time into a cached data file
  (see D5).
- Completing arguments of every nested subcommand exhaustively — cover top-level
  subcommands, their flags, and `--resume`/`--model` values first; deeper
  sub-subcommand flags are a later expansion.

## Decisions

### D1: `#compdef` autoload over manual `compdef` registration
Use a `_claude` file beginning with `#compdef claude` on `$fpath`. This is the
idiomatic compsys pattern, integrates with `compinit` caching, and means the
Oh My Zsh layout works for free (OMZ adds plugin dirs to `$fpath` and runs
`compinit`). `claude.zsh` only needs to prepend the repo dir to `$fpath` and run
`compinit` if it has not already (for the bare `source` install path).

*Alternative considered:* `compdef _claude claude` with the function sourced
directly. Rejected — bypasses autoload/caching and duplicates what `#compdef`
gives for free.

### D2: `_arguments` state machine for the static surface
Drive subcommand/flag parsing with `_arguments -C` and `_describe`. `_arguments`
handles flag/value placement, "don't offer a flag twice", and prefix filtering
natively, which directly satisfies the `static-completion` scenarios. A
`->state` action dispatches dynamic value completion to helper functions.

*Alternative considered:* hand-rolled `compadd` with manual `$words`/`$CURRENT`
inspection. Rejected — re-implements placement logic `_arguments` already does
correctly, and is harder to keep in sync with the spec scenarios.

### D3: Dynamic values via small helper functions in `lib/`
One helper per source: `_claude_models`, `_claude_commands`, `_claude_skills`,
`_claude_sessions`. Each resolves its directory/list from the corresponding
`CLAUDE_AUTOCOMPLETE_*` env var with a documented default, then `compadd`s
candidates. Helpers live in `lib/` and are autoloaded the same way (on `$fpath`)
so they load only when invoked.

- Models: echo `${CLAUDE_AUTOCOMPLETE_MODELS:-<built-in list>}` split on
  whitespace.
- Commands/skills: glob the user dir and the project-local `./.claude/...` dir;
  offer base names; a missing dir yields zero candidates and no error (guarded
  with the `(N)` nullglob qualifier).
- Sessions: see D4.
- `@` paths: detect a leading `@` on the current word and delegate to `_files`
  with the `@` stripped from the prefix.

### D4: Session lookup uses zsh glob qualifiers, not subprocesses
Read session IDs from `${CLAUDE_AUTOCOMPLETE_PROJECTS_DIR:-~/.claude/projects}`.
Sessions live one level deep: `<projects>/<encoded-cwd>/<uuid>.jsonl` (verified
against a real install — the encoded-cwd maps `/` and `.` in the path to `-`).
The session ID is the `.jsonl` base name. Use a zsh glob over the nested level —
`<projects>/*/*.jsonl(.om)` (plain files, ordered by mtime, newest first) —
sliced `[1,N]` to cap results, then strip the `.jsonl` suffix. Globbing happens
in-process — no `find`/`ls`/`stat` fork — which keeps the operation inside the
50 ms budget. Honor `CLAUDE_AUTOCOMPLETE_NO_SESSIONS=1` by returning before
touching the filesystem.

*Refinement (optional):* for relevance, prefer the current project's sessions by
encoding `$PWD` the same way (`/`→`-`, `.`→`-`) and globbing only that subdir,
falling back to all projects. Computing the exact encoding is fragile, so the
default remains the robust all-projects mtime-capped glob.

*Alternative considered:* `find … -printf | sort | head`. Rejected — multiple
forks per `<TAB>` blow the latency budget and add portability concerns.

### D5: Generate the static surface from `--help`, cache by version
The static surface is large and version-dependent: the installed `claude`
(v2.1.156 when validated) exposes ~50 flags, ~12 subcommands, nested
subcommands, and several flags with fixed `choices:` value sets. Hand-curating
this drifts every release. Instead, a generator (`bin/claude-completion-gen`)
runs `claude --help` and `claude <sub> --help`, parses them into zsh data
structures, and writes `lib/_claude_data.zsh`:

- `_claude_subcommands` — name + description pairs (for `_describe`).
- `_claude_flags` — `_arguments`-style specs with descriptions and value-arity,
  derived from each option line (`<x>`/`[x]` ⇒ takes a value; otherwise
  boolean) and the short alias prefix (`-c, --continue`).
- `_claude_choices` — an assoc array flag→choices, extracted from `choices:`
  declarations in the help text.
- `_claude_data_version` — the `claude --version` string this was generated
  from.

Parsing detail: `claude --help` (commander.js) wraps descriptions at terminal
width even under `COLUMNS=9999`; the option *name* line is clean, but
descriptions/`choices:` spill onto continuation lines. The generator dewraps by
treating any line that does not start a new option/command as a continuation of
the previous entry, then extracts `choices:\s*("…"(?:,\s*"…")*)`.

A committed snapshot of `lib/_claude_data.zsh` ships in the repo so completion
works instantly, offline, and never forks `claude` on the hot path. `_claude`
(cheaply) compares `_claude_data_version` to the live `claude --version`; on
mismatch it regenerates once (or prints a one-line hint to run the generator).
This is the answer to "ease of updating commands": a `claude` upgrade refreshes
the completion automatically, with zero manual list maintenance.

*Alternatives considered:* (a) hand-maintained arrays + "open an issue" — the
original plan; rejected for guaranteed drift across ~50 flags and nested
subcommands. (b) Parse `--help` live on every `<TAB>` — authoritative but forks
`claude` per keystroke, blowing the 50 ms budget. The generate-and-cache
approach gets authority *and* speed.

## Risks / Trade-offs

- **Static lists drift from the real CLI** → Keep them in one obvious place,
  document the update path, and prefer additive edits. Optionally add a test
  that diffs against `claude --help` output during development only.
- **Session dir grows large, glob slows down** → The `[1,N]` cap bounds work
  regardless of directory size; mtime ordering keeps the newest sessions on top.
  `CLAUDE_AUTOCOMPLETE_NO_SESSIONS` is the escape hatch.
- **Stale completion cache after a `claude` or repo update** → Documented fix is
  `rm -f ~/.zcompdump* && exec zsh`; surfaced in README troubleshooting.
- **Conflict with a pre-existing `_claude`** → `which _claude` diagnostic in
  README; load order is the user's responsibility via `$fpath` precedence.
- **`@` path detection is heuristic** → Only trigger when the current word
  literally starts with `@`; otherwise fall through to normal completion so we
  never hijack unrelated arguments.

## Migration Plan

Greenfield; nothing to migrate. Rollback = remove the `source` line / plugin
entry and delete the clone (per README Uninstall). No global state is mutated
beyond `$fpath` and the compinit cache.

## Open Questions

- *(Resolved)* Authoritative subcommand/flag list — generated from
  `claude --help` per D5; validated against v2.1.156 (subcommands: `agents`,
  `auth`, `auto-mode`, `doctor`, `install`, `mcp`, `plugin`, `project`,
  `setup-token`, `ultrareview`, `update`; note: there is **no** `config`
  subcommand, contrary to the README example).
- *(Resolved)* Session file naming — IDs are the `<uuid>.jsonl` base names one
  level below the projects dir (`<projects>/<encoded-cwd>/<uuid>.jsonl`); the
  glob is `*/*.jsonl`, not flat.
- How deep to complete **nested** subcommands (e.g. `mcp add`, `plugin enable`):
  the generator can capture them, but the `_arguments` dispatch for sub-sub
  flags is more work — start with top-level subcommands + their flags, expand
  later.
- Whether to show a human-readable label (last-used time / first prompt)
  alongside session IDs via `_describe`, or just raw IDs.
- Regeneration UX on version mismatch: silent background regen vs a one-line
  "run `claude-completion-gen`" hint — silent is smoother but writes into the
  repo dir, which may be read-only for some installs.
