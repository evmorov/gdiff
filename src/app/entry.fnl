(local moves (require :git.moves))

(fn path-text [entry]
  (case entry.kind
    "R" (.. entry.path " <- " entry.old_path)
    "C" (.. entry.path " <- " entry.old_path)
    _ entry.path))

(fn move-note [entry]
  (moves.note entry))

{: move-note : path-text}
