(fn path-text [entry]
  (case entry.kind
    "R" (.. entry.path " <- " entry.old_path)
    "C" (.. entry.path " <- " entry.old_path)
    _ entry.path))

{: path-text}
