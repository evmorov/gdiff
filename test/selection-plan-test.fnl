(local faith (require :faith))
(local plan (require :app.selection-plan))

(fn test-flat-index-clamps-to-entry-count []
  (faith.= 1 (plan.flat-index [] 1 1))
  (faith.= 1 (plan.flat-index [{} {}] 1 -1))
  (faith.= 2 (plan.flat-index [{} {}] 1 1))
  (faith.= 2 (plan.flat-index [{} {}] 2 1)))

(fn test-changed-detects-real-changes []
  (faith.= false (plan.changed? 1 1))
  (faith.= true (plan.changed? 1 2)))

{: test-changed-detects-real-changes : test-flat-index-clamps-to-entry-count}
