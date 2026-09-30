(fn for-entry [revision entry ?full-context? ?hide-comments? ?highlight?]
  (.. revision "\0" entry.status "\0" (or entry.old_path "") "\0" entry.path
      "\0" (or entry.moved_from entry.moved_to "")
      (if ?full-context? "\0full" "") (if ?hide-comments? "\0nocomments" "")
      (if ?highlight? "\0syntax" "")))

(fn for-settings [settings entry]
  (for-entry settings.revision entry settings.full-context?
             settings.hide-comments? (?. settings :highlight :on?)))

(fn for-listing [path ?highlight?]
  (.. "listing\0" path (if ?highlight? "\0syntax" "")))

{: for-entry : for-listing : for-settings}
