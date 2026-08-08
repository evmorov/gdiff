# gdiff

A tiny Fennel TUI for opening files changed by a Git revision range.

```sh
bin/gdiff main HEAD
```

You can also pass a GitHub PR URL. gdiff resolves the PR via `gh` and diffs
the remote refs only: the base branch is refreshed from `origin`, and the
head is the fetched `origin/<branch>` — or the permanent PR head ref when
the branch was deleted — so the diff matches what GitHub shows regardless
of your local branches. The header shows the PR URL:

```sh
bin/gdiff https://github.com/owner/repo/pull/123
```

Run tests with:

```sh
bin/test
```

Tests use the vendored [Faith](https://git.sr.ht/~technomancy/faith) runner and
the installed `fennel` command.

Architecture:

- `src/args.fnl` parses CLI arguments.
- `src/update.fnl` owns app state transitions: raw keys become messages, and
  `update` returns the state plus an optional command.
- `src/commands.fnl` owns side-effect commands. Commands receive `dispatch` and
  `get-state`, do I/O, then dispatch result messages back through `update`.
- `src/view.fnl` renders the current state for the TUI.
- `src/app.fnl` wires Git data, config, state, update, view, and the terminal
  loop together.

Use a different editor for one run:

```sh
bin/gdiff --editor nvim main HEAD
bin/gdiff -e "idea --wait" main HEAD
```

Press `?` inside gdiff for keyboard shortcuts. Run `bin/gdiff --help` for CLI
usage.

Config lives at:

```text
~/.config/gdiff/config.fnl
```

Example:

```fennel
{:editor "nvim"}
```

The editor can be a command string:

```fennel
{:editor "idea --wait"}
```

Or a list, which is safer when the executable path contains spaces:

```fennel
{:editor ["/Applications/IntelliJ IDEA.app/Contents/MacOS/idea" "--wait"]}
```

If there is no config, `gdiff` uses `GDIFF_EDITOR`, then `VISUAL`, then
`EDITOR`, then `vim`.

An inline `--editor` / `-e` option overrides the config and environment for
that run.
