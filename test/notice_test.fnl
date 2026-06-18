(local faith (require :faith))
(local notice (require :app.notice))

(fn test-path_notices []
  (faith.= "Copied: a.rb" (notice.copy-finished true "a.rb"))
  (faith.= "Copy failed: a.rb" (notice.copy-finished false "a.rb"))
  (faith.= "Opening: src" (notice.open-target-finished :folder "src" true))
  (faith.= "Folder not found: src"
           (notice.open-target-finished :folder "src" false))
  (faith.= "File not found: a.rb"
           (notice.open-target-finished :file "a.rb" false)))

(fn test-review_notices []
  (faith.= "Marked reviewed: a.rb"
           (notice.reviewed-entry {:path "a.rb" :reviewed true}))
  (faith.= "Unmarked reviewed: a.rb"
           (notice.reviewed-entry {:path "a.rb" :reviewed false}))
  (faith.= "Marked folder reviewed: src/" (notice.reviewed-folder true "src/"))
  (faith.= "Unmarked all reviewed" (notice.reviewed-all false)))

(fn test_misc_notices []
  (faith.= "Opened PR: https://example.com"
           (notice.open-pr-finished true "https://example.com" nil))
  (faith.= "No linked PR" (notice.open-pr-finished false nil nil))
  (faith.= "No linked PR for feature"
           (notice.open-pr-finished false nil "No linked PR for feature"))
  (faith.= "Could not save reviewed marks" (notice.review-persist-failed))
  (faith.= "Syncing remote..." (notice.syncing-remote))
  (faith.= "Remote in sync" (notice.remote-in-sync)))

{: test_misc_notices : test-path_notices : test-review_notices}
