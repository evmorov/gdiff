(fn for-entry [revision entry ?full-context?]
  (.. revision "\0" entry.status "\0" (or entry.old_path "") "\0" entry.path
      (if ?full-context? "\0full" "")))

{: for-entry}
