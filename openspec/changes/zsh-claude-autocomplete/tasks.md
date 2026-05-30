## 1. Scaffold & loading

- [x] 1.1 Create repo layout: `claude.zsh` (entry point), `_claude` (completion function), `lib/` dir
- [x] 1.2 In `claude.zsh`: prepend repo dir to `$fpath`, run `compinit` only if not already initialized, so a bare `source` install works
- [x] 1.3 Add `#compdef claude` as the first line of `_claude` so it autoloads via `compinit`
- [x] 1.4 Verify `claude <TAB>` triggers the function in a fresh shell (source path) and via `$fpath`+`compinit` (autoload path)

## 2. Completion data (generated from `--help`)

- [x] 2.1 Write `bin/claude-completion-gen`: run `claude --help` (top-level only — per-subcommand `claude <sub> --help` parsing deferred, see Contributing), dewrap commander's width-wrapped descriptions, parse into `_claude_subcommands`, `_claude_flags` (name + desc + value-arity), `_claude_choices` (flag→choices assoc), and `_claude_data_version`
- [x] 2.2 Extract value-arity from each option line (`<x>`/`[x]` ⇒ takes value; else boolean) and the short alias prefix (`-c, --continue`); extract `choices:` lists via regex on the dewrapped block
- [x] 2.3 Emit `lib/_claude_data.zsh` and commit a generated snapshot (so completion works offline / without running the generator); record the source `claude --version`
- [x] 2.4 Add version-check in `_claude`/`claude.zsh`: compare `_claude_data_version` to live `claude --version`; on mismatch regenerate once (or print a one-line hint). Never invoke `claude` on the completion hot path
- [x] 2.5 Verify against v2.1.156: no `config` subcommand; `agents/auth/auto-mode/doctor/install/mcp/plugin/project/setup-token/ultrareview/update` present

## 3. Static completion (subcommands & flags)

- [x] 3.1 Build the `_arguments -C` state machine from the data file: offer subcommands in first arg position, flags when word starts with `-`, with `_describe` descriptions
- [x] 3.2 Ensure non-repeatable flags are not offered twice and the subcommand list is not repeated after a subcommand is chosen
- [x] 3.3 Add `->state` dispatch so value-taking flags route to dynamic helpers and boolean flags (e.g. `--continue`) take no value
- [x] 3.4 Complete enumerated flag values from `_claude_choices`: `--permission-mode` (acceptEdits/auto/bypassPermissions/default/dontAsk/plan), `--output-format` (text/json/stream-json), `--input-format` (text/stream-json), `--effort` (low/medium/high/xhigh/max)

## 4. Dynamic value helpers (`lib/`)

- [x] 4.1 `_claude_models`: emit `${CLAUDE_AUTOCOMPLETE_MODELS:-<built-in list>}` split on whitespace as `--model` values; built-in list includes aliases (`opus`, `sonnet`, `haiku`) and full IDs (`claude-opus-4-8`, `claude-sonnet-4-6`, ...)
- [x] 4.2 `_claude_commands`: glob user dir (`${CLAUDE_AUTOCOMPLETE_COMMANDS_DIR:-~/.claude/commands}`) and project-local `./.claude/commands`, offer base names, guard missing dirs with `(N)` nullglob
- [x] 4.3 `_claude_skills`: glob user dir (`${CLAUDE_AUTOCOMPLETE_SKILLS_DIR:-~/.claude/skills}`) and project-local `./.claude/skills`, offer skill names, guard missing dirs
- [x] 4.4 `_claude_sessions`: glob `${CLAUDE_AUTOCOMPLETE_PROJECTS_DIR:-~/.claude/projects}/*/*.jsonl` (nested one level) with `(.om)` qualifier, slice `[1,N]` to cap, offer session IDs (basenames minus `.jsonl`) for `--resume`; return early if `CLAUDE_AUTOCOMPLETE_NO_SESSIONS=1`
- [ ] 4.5 (optional, deferred) prefer current-project sessions by encoding `$PWD` (`/`→`-`, `.`→`-`) to the project subdir, falling back to all projects
- [x] 4.6 `@`-path completion: when current word starts with `@`, strip the `@` and delegate to `_files`/`_path_files`; otherwise fall through

## 5. Configuration & defaults

- [x] 5.1 Confirm every `CLAUDE_AUTOCOMPLETE_*` var falls back to its documented default when unset
- [x] 5.2 Verify directory overrides (`*_COMMANDS_DIR`, `*_SKILLS_DIR`, `*_PROJECTS_DIR`) are honored and `*_NO_SESSIONS=1` disables session lookup entirely

## 6. Performance

- [x] 6.1 Confirm session lookup and data reads use only zsh-native globbing / file reads (no `find`/`ls`/`stat` and no `claude` forks on the hot path)
- [x] 6.2 Measure session completion latency against a realistic projects dir; confirm <50 ms and that the `[1,N]` cap bounds work regardless of dir size

## 7. Install methods

- [x] 7.1 Validate Option A/B installs (one-liner `source`; manual `fpath`+`compinit`)
- [x] 7.2 Validate Oh My Zsh plugin layout (`zsh-claude-completions.plugin.zsh` present, sources `claude.zsh`; standard OMZ fpath+autoload mechanism — not exercised under a live OMZ install in this environment)

## 8. Tests & docs

- [x] 8.1 Add `test/run.sh` covering each spec scenario (subcommand/flag placement, value routing, enumerated choices, dynamic sources, missing-dir no-error, sessions on/off)
- [x] 8.2 Add a generator test: parse a captured `claude --help` fixture and assert subcommands/flags/choices/version are extracted (incl. dewrapping of wrapped descriptions)
- [x] 8.3 Reconcile README (install/config/troubleshooting) with shipped behavior; fix drift (e.g. drop the non-existent `config` subcommand example)
- [x] 8.4 Document the update path: run `bin/claude-completion-gen` to refresh `lib/_claude_data.zsh`, and how the auto-refresh-on-version-change works
