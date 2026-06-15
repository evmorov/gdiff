# gdiff

A tiny Fennel TUI for opening files changed by a Git revision range.

```sh
bin/gdiff main...HEAD
```

Keys:

- `j` / down arrow: next file
- `k` / up arrow: previous file
- `space`: mark selected file as reviewed, or unmark it
- `enter` / `o`: open selected file
- `q`: quit

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
