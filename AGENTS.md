# Agent Notes

This file is for coding agents working on gdiff. Keep README.md
focused on users; put contributor and agent workflow details here.

## Project Shape

- Runtime entrypoint: `bin/gdiff` runs `src/main.fnl` with the installed
  `fennel` command.
- App orchestration lives under `src/app/`. The important flow is:
  `input -> message -> update -> command -> message -> view`.
- Git integration lives under `src/git/`.
- Preview caching and workers live under `src/preview/`.
- Persistence lives under `src/storage/`.
- Platform adapters live under `src/platform/`.
- TUI framework code lives under `src/tui/`; app-specific rendering lives under
  `src/app/view/`.
- Shared small helpers live under `src/util/`.
- Tests live in `test/` and use the vendored Faith runner.

## Fennel

- Use the installed commands: `fennel`, `fnlfmt`, and `fennel-ls`.
- Do not introduce LuaRocks as part of normal development. The app is expected
  to work through the available `fennel` command.
- Prefer the local official Fennel docs over web search. They are on disk at
  `~/projects/fennel-books/fennel-docs`; check them before
  changing syntax, macro usage, module style, or formatting assumptions. If that
  directory is missing in a checkout, say so instead of guessing from memory.
- Use modern Fennel idioms when they improve clarity: table shorthand, `#()`
  shorthand for small functions, `collect` / `fcollect` for transformations,
  and macros only when they remove real repetition without hiding behavior.
- Follow official Fennel naming conventions: variables, functions, modules,
  and Fennel filenames should use lowercase words separated by hyphens. Use
  leading `_` only for intentionally unused bindings and leading `?` for values
  that may be nil. Underscores are acceptable for persisted data fields,
  external API compatibility, environment variables, and Lua-facing exported
  module fields when needed, but keep the internal Fennel binding hyphenated.
- Keep macros small and local. Existing macros are in `src/app/macros.fnlm`,
  `src/state/macros.fnlm`, and `src/tui/macros.fnlm`.

## FP and TEA Style

- The local TEA Fennel course is at
  `~/projects/fennel-books/tea-fennel`. Use it as the
  project reference for TEA decisions, especially message/update/command shape.
- Favor functions that transform data and return new values over functions that
  mutate broad shared state. Mutation is fine at the app boundary and in
  intentionally stateful runtime code, but isolate it.
- Keep decision logic as data where possible: messages, actions, command
  descriptors, render nodes, preview plans, and layout records should be plain
  tables that are easy to test.
- Compose small helpers with explicit inputs. Avoid hidden reads from global
  state when the caller can pass the needed state, config, width, path, or entry.
- Separate pure planning from effects. For example, build git commands, preview
  warming plans, render rows, and scroll calculations in pure helpers; execute
  shell commands, file I/O, clipboard, browser, and terminal writes at the edge.
- Use pipelines of collection transforms when they read naturally, but keep the
  code debuggable. Prefer named intermediate helpers over dense anonymous logic.
- Add tests around pure helpers and TEA update flows. High-level behavior tests
  are preferred; lower-level tests are useful for parsing, layout, and boundary
  calculations.

## Checks

Run the narrowest useful tests while working, then run the full suite before
finishing:

```sh
bin/test
```

Lint Fennel source and macros with:

```sh
fennel-ls --lint $(rg --files -g "*.fnl" src test examples)
fennel-ls --lint $(rg --files -g "*.fnlm" src)
```

Format changed Fennel files with:

```sh
fnlfmt --fix path/to/file.fnl
```

For broad formatting, use:

```sh
fnlfmt --fix $(rg --files -g "*.fnl" -g "*.fnlm" src test examples)
```

## Working Style

- Read the nearby modules before editing. The codebase is intentionally split by
  responsibility; keep new behavior in the same layer as similar behavior.
- Preserve the TEA-like shape in app code: model state changes as data messages,
  keep side effects in command modules, and keep rendering in view modules.
- Prefer pure helpers for parsing, planning, layout, and formatting. Add tests at
  the highest practical level first, then cover lower-level helpers where useful.
- TUI changes should go through `src/tui/` components when they are reusable, and
  through `src/app/view/` only when they are specific to gdiff.
- Be careful with terminal behavior. Pasted text must not become commands, and
  long-running work must not make cursor movement feel laggy.
- Do not inspect or mutate git state just to review your own changes; the user
  handles git. Run git commands only when the task explicitly needs repository
  data or the user asks for it.
- Avoid unrelated refactors. If a cleanup is worthwhile, keep it small, tested,
  and aligned with the existing folder boundaries.
- Add code comments only if they are absolutely necessary.
