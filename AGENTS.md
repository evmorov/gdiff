# Agent Notes

This file is for coding agents working on gdiff. Keep README.md focused on users; put contributor and agent workflow details here.

## Project Shape

gdiff is a Fennel TUI that runs on the installed `fennel` command. There is no build step and no LuaRocks. `bin/gdiff` runs `src/main.fnl`, which adds `src/` to the Fennel and macro paths and calls `app.core`.

- `src/app/`: the application. `core.fnl` wires arguments, git data, config, review storage, state, update, and view into `tui.run`.
- `src/app/view/`: gdiff-specific rendering. `left.fnl` is the file list, `preview.fnl` the unified diff, `preview-split.fnl` the side-by-side diff, `chrome.fnl` the header and footer, `help.fnl` the shortcut modal.
- `src/git/`: git command builders, diff parsing, blame, move detection, code stats, PR resolution, and remote sync status.
- `src/preview/`: diff-to-rows planning, word-level diff, line moves, folder and asset previews, the preview cache, and background warming workers.
- `src/storage/`: config file and persisted review marks.
- `src/platform/`: shell, clipboard, browser, editor, and `fennel` subprocess adapters. All process and file I/O should go through here.
- `src/tui/`: the reusable terminal framework: raw terminal handling, key parsing, render nodes, components, theme, text width and wrapping.
- `src/util/`: small pure helpers for strings, math, and scrolling.
- `src/state/macros.fnlm`, `src/app/macros.fnlm`, `src/tui/macros.fnlm`: the only macro files. See Macros below.
- `test/`: Faith tests. `test/run.fnl` lists every test module, `test/test-helper.fnl` builds temporary git repositories for tests.
- `examples/config.fnl`: sample user config, linted and formatted with the rest of the code.

## TEA Flow

App code follows a TEA-like loop. Keep new behavior in the matching step.

1. `tui/runtime.fnl` reads a key and calls the app `update` function.
2. `app/input.fnl` maps keys to message types. `app/messages.fnl` builds message tables. Every message is a plain table with a `:type` field.
3. `app/update.fnl` dispatches on `msg.type` to a handler. Handlers mutate the state table and return a command.
4. Commands live in `app/commands.fnl`. A command is a function of `[dispatch get-state]`, created with `defcommand`. Commands do the I/O and dispatch result messages such as `copy-path-finished`.
5. `app/command-runner.fnl` runs the command, then drains the queue of messages it dispatched through `update` until nothing is left.
6. `app/view.fnl` and `app/view/*` turn state into `tui/nodes` render nodes. `tui/draw.fnl` and the components render them.

Rules that fall out of this:

- Key handling belongs in `input.fnl`, not in view or command code.
- Anything that shells out, reads or writes files, touches the clipboard, or opens a browser or editor goes through a `platform` function and is triggered from a command. Handlers in `update.fnl` and `actions.fnl` should only change state. The existing exceptions are loading a preview on a cache miss and polling the sync status file. Do not add new I/O to handlers.
- Planning is separate from doing. `action-plan.fnl`, `selection-plan.fnl`, `search-plan.fnl`, `preview/warm-plan.fnl`, and `git/commands.fnl` build plain data or command strings. The effectful code executes them.
- View `body` functions must not mutate state. `view-purity-test.fnl` checks this. Views that need to compute layout do so in a `prepare` function that runs before drawing.

## Preview Pipeline

- `preview/core.fnl` owns the preview cache keyed by `preview/key.fnl`. It decides between diff, full-file, folder, and asset previews.
- `preview/diff-parse.fnl` parses unified diff text into handler callbacks. `preview/format.fnl` renders unified rows, `preview/split.fnl` renders side-by-side rows. Both use `preview/word-diff.fnl` for line alignment and word emphasis, and `preview/line-moves.fnl` for moved-line marks.
- `preview/warm.fnl` spawns `fennel` subprocesses running `preview/worker.fnl` to fill the cache in the background. They communicate through a temp directory with a manifest and one output file per entry. `preview/workers.fnl` decides how many workers to start.
- Cursor movement must not wait for warming. Do not add blocking work to the key loop.

## Fennel

- Use the installed commands: `fennel`, `fnlfmt`, and `fennel-ls`.
- Do not introduce LuaRocks or other dependencies. Faith is vendored in `test/faith.fnl`.
- The Fennel reference and style guide are at https://fennel-lang.org. Check them before changing syntax, macro usage, or module style rather than guessing from memory.
- Prefer modern Fennel idioms when they improve clarity: table shorthand, `#()` for small functions, `collect`, `icollect`, `fcollect`, and `accumulate` for transformations, `case` for dispatch on data.
- Modules return a table of exports at the bottom of the file. Use the `{: a : b}` shorthand.

### Naming

- Fennel bindings, functions, modules, and filenames use lowercase words separated by hyphens.
- Leading `?` marks a value that may be nil. Leading `_` marks an intentionally unused binding. Trailing `?` marks a boolean or predicate.
- The app state table uses snake_case fields, for example `preview_wrap?` and `show_numbers?`. This is the existing convention for state; new state fields should match their neighbors. Row, message, and plan records use hyphenated keys, for example `old-no` and `pending-key`.
- Underscores are also fine for persisted data fields, environment variables, and Lua-facing exports when needed.

### Macros

Keep macros small and local. The existing ones are:

- `defcommand` in `src/app/macros.fnlm`: defines a command constructor that returns a `[dispatch get-state]` closure.
- `set-fields` in `src/state/macros.fnlm`: sets several fields on one table.
- `defnode` and `defrenderer` in `src/tui/macros.fnlm`: define render node constructors and register component renderers.

Add a macro only when it removes real repetition without hiding behavior.

## FP Style

- Favor functions that transform data and return new values. Mutation is fine at the app boundary, in `update` handlers, and in intentionally stateful runtime code, but keep it isolated and obvious.
- Keep decision logic as data: messages, plans, render nodes, rows, and layout records are plain tables that tests can compare with `faith.=`.
- Pass what a function needs explicitly: state, config, width, path, entry. Avoid reading globals or module-level mutable state.
- Prefer named intermediate helpers over dense anonymous pipelines. The code should be easy to step through.

## Tests

`bin/test` is the full check. It runs, in order:

1. `fnlfmt --check` on every `.fnl` and `.fnlm` file. Unformatted files fail the run.
2. `fennel-ls --lint` on the same files.
3. `test/run.fnl` from a fresh temp directory with `HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `GDIFF_TEST_ROOT` pointing into it, so tests never touch the real config or review store.

Conventions:

- One test module per source area, named `<area>-test.fnl`. A module exports a table of `test-*` functions. New modules must be added to the list in `test/run.fnl` or they will not run.
- Prefer high-level behavior tests: drive `app.update` with messages, or parse a small diff string and compare the resulting rows. Add lower-level tests for parsing, layout, and boundary math where they help.
- Tests that need a git repository use `test-helper.fnl`, which creates and resets a repo inside `GDIFF_TEST_ROOT`.

Run a few modules while working, without lint or the temp repo, for pure tests only:

```sh
fennel --add-fennel-path "src/?.fnl;test/?.fnl" --add-macro-path "src/?.fnlm;src/?.fnl" -e '((. (require :faith) :run) [:preview-split-test :preview-word-diff-test])'
```

Run everything before finishing:

```sh
bin/test
```

Format changed files with:

```sh
fnlfmt --fix path/to/file.fnl
```

Lint by hand with:

```sh
fennel-ls --lint $(rg --files -g "*.fnl" src test examples)
fennel-ls --lint $(rg --files -g "*.fnlm" src)
```

## Docs To Keep In Sync

- `README.md` has the user-facing feature list and usage. Update it when a feature is added or changed.
- `src/app/view/help.fnl` holds the shortcut list shown by `?`. Update it when a key binding changes in `src/app/input.fnl`.
- `src/app/args.fnl` holds the `--help` text. Update it when CLI options or argument forms change.
- Write docs in plain language with full lines; do not wrap at 80 columns. State what a feature does and stop. No marketing tone, no claims like "fast" or "instant".

## Working Style

- Read the nearby modules before editing. The codebase is split by responsibility; keep new behavior in the same layer as similar behavior.
- TUI changes go through `src/tui/` when they are reusable and through `src/app/view/` only when they are specific to gdiff.
- Be careful with terminal behavior. Pasted text must not become commands, and long-running work must not block cursor movement.
- Do not inspect or mutate git state just to review your own changes; the user handles git. Run git commands only when the task needs repository data or the user asks for it.
- Avoid unrelated refactors. If a cleanup is worthwhile, keep it small, tested, and inside the existing folder boundaries.
- Add code comments only when absolutely necessary.
