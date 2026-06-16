(fn for-entry [revision entry]
  (.. revision "\0" entry.status "\0" (or entry.old_path "") "\0" entry.path))

{: for-entry}
