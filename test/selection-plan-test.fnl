(local faith (require :faith))
(local plan (require :app.selection-plan))

(fn test-flat-index-clamps-to-entry-count []
  (faith.= 1 (plan.flat-index [] 1 1))
  (faith.= 1 (plan.flat-index [{} {}] 1 -1))
  (faith.= 2 (plan.flat-index [{} {}] 1 1))
  (faith.= 2 (plan.flat-index [{} {}] 2 1)))

(fn test-selected-row-index-uses-tree-row-when-available []
  (faith.= 4 (plan.selected-row-index :tree 4 2 9))
  (faith.= 9 (plan.selected-row-index :tree nil 2 9))
  (faith.= 2 (plan.selected-row-index :flat nil 2 9)))

(fn test-changed-detects-real-changes []
  (faith.= false (plan.changed? 1 1))
  (faith.= true (plan.changed? 1 2)))

{: test-changed-detects-real-changes
 : test-flat-index-clamps-to-entry-count
 : test-selected-row-index-uses-tree-row-when-available}
