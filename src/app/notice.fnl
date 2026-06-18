(fn with-path [action path]
  (.. action ": " path))

(fn copy-finished [ok? path]
  (with-path (if ok? "Copied" "Copy failed") path))

(fn open-pr-finished [ok? ?url ?error]
  (if ok?
      (.. "Opened PR: " ?url)
      (or ?error "No linked PR")))

(fn open-target-action [target ok?]
  (if ok? "Opening"
      (= target :folder) "Folder not found"
      "File not found"))

(fn open-target-finished [target path ok?]
  (with-path (open-target-action target ok?) path))

(fn reviewed-entry [entry]
  (with-path (if entry.reviewed "Marked reviewed" "Unmarked reviewed")
    entry.path))

(fn reviewed-folder [review? name]
  (with-path (if review?
                 "Marked folder reviewed"
                 "Unmarked folder reviewed")
    name))

(fn reviewed-all [review?]
  (if review?
      "Marked all reviewed"
      "Unmarked all reviewed"))

(fn review-persist-failed []
  "Could not save reviewed marks")

(fn syncing-remote []
  "Syncing remote...")

(fn remote-in-sync []
  "Remote in sync")

{: copy-finished
 : open-pr-finished
 : open-target-action
 : open-target-finished
 : remote-in-sync
 : review-persist-failed
 : reviewed-all
 : reviewed-entry
 : reviewed-folder
 : syncing-remote
 : with-path}
