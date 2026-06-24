(local faith (require :faith))
(local notice (require :app.notice))

(fn test-path-notices []
  (faith.= "Copied: a.rb" (notice.copy-finished true "a.rb"))
  (faith.= "Copy failed: a.rb" (notice.copy-finished false "a.rb"))
  (faith.= "Opening: src" (notice.open-target-finished :folder "src" true))
  (faith.= "Folder not found: src"
           (notice.open-target-finished :folder "src" false))
  (faith.= "File not found: a.rb"
           (notice.open-target-finished :file "a.rb" false)))

(fn test-yank-notices []
  (faith.= "Copied 1 line" (notice.yank-finished true 1))
  (faith.= "Copied 2 lines" (notice.yank-finished true 2))
  (faith.= "Copy failed" (notice.yank-finished false 2))
  (faith.= "Copied a.rb (1 line, fenced)"
           (notice.yank-fenced-finished true "a.rb" 1))
  (faith.= "Copied src/a.rb (3 lines, fenced)"
           (notice.yank-fenced-finished true "src/a.rb" 3))
  (faith.= "Copy failed" (notice.yank-fenced-finished false "a.rb" 3)))

(fn test-review-notices []
  (faith.= "Marked reviewed: a.rb"
           (notice.reviewed-entry {:path "a.rb" :reviewed true}))
  (faith.= "Unmarked reviewed: a.rb"
           (notice.reviewed-entry {:path "a.rb" :reviewed false}))
  (faith.= "Marked folder reviewed: src/" (notice.reviewed-folder true "src/"))
  (faith.= "Unmarked all reviewed" (notice.reviewed-all false)))

(fn test-misc-notices []
  (faith.= "Opened PR: https://example.com"
           (notice.open-pr-finished true "https://example.com" nil))
  (faith.= "No linked PR" (notice.open-pr-finished false nil nil))
  (faith.= "No linked PR for feature"
           (notice.open-pr-finished false nil "No linked PR for feature"))
  (faith.= "Could not save reviewed marks" (notice.review-persist-failed))
  (faith.= "Syncing remote..." (notice.syncing-remote))
  (faith.= "Remote in sync" (notice.remote-in-sync)))

{: test-misc-notices
 : test-path-notices
 : test-review-notices
 : test-yank-notices}
