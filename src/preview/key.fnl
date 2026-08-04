(fn for-entry [revision entry ?full-context? ?hide-comments?]
  (.. revision "\0" entry.status "\0" (or entry.old_path "") "\0" entry.path
      (if ?full-context? "\0full" "") (if ?hide-comments? "\0nocomments" "")))

{: for-entry}
