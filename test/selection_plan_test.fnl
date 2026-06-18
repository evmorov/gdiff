(local faith (require :faith))
(local plan (require :app.selection_plan))

(fn test-flat_index_clamps_to_entry_count []
  (faith.= 1 (plan.flat-index [] 1 1))
  (faith.= 1 (plan.flat-index [{} {}] 1 -1))
  (faith.= 2 (plan.flat-index [{} {}] 1 1))
  (faith.= 2 (plan.flat-index [{} {}] 2 1)))

(fn test-selected_row_index_uses_tree_row_when_available []
  (faith.= 4 (plan.selected-row-index :tree 4 2 9))
  (faith.= 9 (plan.selected-row-index :tree nil 2 9))
  (faith.= 2 (plan.selected-row-index :flat nil 2 9)))

(fn test-changed_detects_real_changes []
  (faith.= false (plan.changed? 1 1))
  (faith.= true (plan.changed? 1 2)))

{: test-changed_detects_real_changes
 : test-flat_index_clamps_to_entry_count
 : test-selected_row_index_uses_tree_row_when_available}
