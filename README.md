# zsh-claude-completions

Zsh shell-level autocomplete for the [Claude Code](https://docs.claude.com/claude-code) CLI (`claude`).

Adds completion for:
- Subcommands (`mcp`, `plugin`, `agents`, `update`, `doctor`, ...) — derived
  automatically from `claude --help`, so they track the installed CLI.
- Flags (`--model`, `--continue`, `--resume`, `--print`, `--permission-mode`,
  `--effort`, `--dangerously-skip-permissions`, ...) with descriptions.
- Enumerated flag values (`--permission-mode`, `--output-format`,
  `--input-format`, `--effort`).
- Model IDs and aliases (`opus`, `sonnet`, `haiku`, `claude-opus-4-8`,
  `claude-sonnet-4-6`, ...)
- Slash-command names from `~/.claude/commands/` and `./.claude/commands/`
  (after a leading `/`)
- Skill names from `~/.claude/skills/` and `./.claude/skills/`
- Session IDs for `--resume` (read from `~/.claude/projects/`)
- File paths after `@`

> **Note:** This is shell-level completion (Tab key in zsh). The interactive REPL inside `claude` already has its own built-in completion — this project does **not** replace that.

---

## Requirements

- macOS or Linux
- zsh 5.0+ (`echo $ZSH_VERSION`)
- `claude` CLI installed and on `$PATH` (`which claude`)

Bash and fish are not supported yet (PRs welcome).

---

## Install

### Option 0 — from a local checkout (no clone)

If you already have this repo on disk (e.g. you cloned or are developing it),
point `~/.zshrc` straight at it — replace the path with your checkout:

```bash
echo 'source /path/to/zsh-claude-completions/claude.zsh' >> ~/.zshrc
exec zsh
```

That's it — `claude.zsh` adds itself to `$fpath`, runs `compinit` if needed, and
registers the completion. Verify with `claude <TAB>` (see [Verify](#verify)).

The options below clone from GitHub instead (use once the repo is published).

### Option A — one-liner (recommended)

```bash
git clone https://github.com/ivolkoff/zsh-claude-autocomplete.git ~/.zsh-claude-completions
echo 'source ~/.zsh-claude-completions/claude.zsh' >> ~/.zshrc
exec zsh
```

### Option B — manual

1. Clone anywhere:
   ```bash
   git clone https://github.com/ivolkoff/zsh-claude-autocomplete.git ~/.zsh-claude-completions
   ```
2. Add to `~/.zshrc`:
   ```bash
   fpath=(~/.zsh-claude-completions $fpath)
   autoload -Uz compinit && compinit
   source ~/.zsh-claude-completions/claude.zsh
   ```
3. Reload:
   ```bash
   exec zsh
   ```

### Option C — Oh My Zsh plugin

```bash
git clone https://github.com/ivolkoff/zsh-claude-autocomplete.git \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-claude-completions
```

Add `zsh-claude-completions` to the `plugins=(...)` array in `~/.zshrc`, then `exec zsh`.

---

## Verify

```bash
claude <TAB>         # should list subcommands
claude --m<TAB>      # should expand to --model and offer model IDs
claude --resume <TAB># should list recent session IDs
```

If nothing happens, see [Troubleshooting](#troubleshooting).

---

## Update

You clone once; after that you **pull** — never clone again. If you re-run the
install one-liner you'll get
`fatal: destination path '...' already exists and is not an empty directory` —
that just means it's already installed. Update it instead:

```bash
cd ~/.zsh-claude-completions && git pull && exec zsh
```

Or for Oh My Zsh:

```bash
cd ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-claude-completions && git pull && exec zsh
```

`exec zsh` reloads the shell so the new completion is picked up. If completion
behaves stale after an update, clear the zsh completion cache:

```bash
rm -f ~/.zcompdump* && exec zsh
```

You do **not** need to pull when the `claude` CLI itself updates — the
completion notices the new `claude --version` and refreshes its own data
automatically (see [How completion data stays current](#how-completion-data-stays-current)).

---

## Uninstall

1. Remove the `source` line (or plugin entry) from `~/.zshrc`.
2. Delete the clone:
   ```bash
   rm -rf ~/.zsh-claude-completions
   ```
3. Clear cache:
   ```bash
   rm -f ~/.zcompdump* && exec zsh
   ```

---

## Configuration

Override defaults by exporting before sourcing:

| Variable                          | Default                       | Purpose                                  |
| --------------------------------- | ----------------------------- | ---------------------------------------- |
| `CLAUDE_AUTOCOMPLETE_MODELS`      | built-in list                 | Space-separated model IDs to offer       |
| `CLAUDE_AUTOCOMPLETE_COMMANDS_DIR`| `~/.claude/commands`          | Where to look for slash commands         |
| `CLAUDE_AUTOCOMPLETE_SKILLS_DIR`  | `~/.claude/skills`            | Where to look for skills                 |
| `CLAUDE_AUTOCOMPLETE_PROJECTS_DIR`| `~/.claude/projects`          | Where to look for session IDs            |
| `CLAUDE_AUTOCOMPLETE_NO_SESSIONS` | unset                         | Set `=1` to skip session-ID completion   |

Example:

```bash
export CLAUDE_AUTOCOMPLETE_MODELS="claude-opus-4-8 claude-sonnet-4-6"
source ~/.zsh-claude-completions/claude.zsh
```

---

## Troubleshooting

**`claude <TAB>` does nothing**
- Confirm `compinit` ran: `print -l $fpath | grep zsh-claude-completions`
- Reload: `exec zsh`
- Clear cache: `rm -f ~/.zcompdump* && exec zsh`

**Completions are out of date after a `claude` update**
- They self-heal: the completion records the `claude` version it was generated
  for and regenerates automatically (into `${XDG_CACHE_HOME:-~/.cache}/zsh-claude-completions`)
  the first time it notices the installed `claude --version` changed.
- To refresh the committed snapshot manually: `bin/claude-completion-gen`
- To disable the auto-refresh: `export CLAUDE_AC_NO_REFRESH=1`

**Conflict with another `_claude` completion**
- Check: `which _claude` — should point to this repo. Remove the other source.

---

## Project layout

```
zsh-claude-completions/
├── README.md                         # this file
├── claude.zsh                        # entry point sourced from ~/.zshrc
├── zsh-claude-completions.plugin.zsh # Oh My Zsh entry (sources claude.zsh)
├── _claude                           # zsh completion function (autoloaded via fpath)
├── bin/
│   └── claude-completion-gen         # generates lib/_claude_data.zsh from `claude --help`
├── lib/
│   ├── _claude_data.zsh              # generated, version-pinned snapshot (subcommands/flags/choices)
│   └── _claude_sources.zsh           # dynamic value sources (models, commands, skills, sessions)
└── test/
    ├── run.sh                        # unit tests (pure logic)
    ├── integration.zsh               # live completion smoke test (zpty)
    └── fixtures/                     # captured `claude --help` for the generator tests
```

## How completion data stays current

The static surface (subcommands, flags, value-arity, descriptions, enumerated
choices) is **generated** from `claude --help` by `bin/claude-completion-gen`,
not hand-maintained. A version-pinned snapshot (`lib/_claude_data.zsh`) ships in
the repo so completion works instantly and offline — completion never runs
`claude` while you type. When the installed `claude --version` no longer matches
the snapshot, the function regenerates once into your cache directory. Run
`bin/claude-completion-gen` to refresh the committed snapshot.

---

## Contributing

PRs welcome for:
- Bash / fish support
- Nested subcommand completion (e.g. `claude mcp <sub>`) — currently only
  top-level subcommands and the global flags are completed
- Performance fixes (session lookup must stay <50 ms)

Run the tests with:

```bash
./test/run.sh          # unit tests (pure logic, no tty needed)
./test/integration.zsh # live completion via zpty (needs a usable pty)
```

---

## License

MIT
