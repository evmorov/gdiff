(local preview (require :preview.core))
(local selection-plan (require :app.selection-plan))
(local tree (require :app.tree))

(fn flat-rows [entries]
  (icollect [index entry (ipairs entries)]
    {:type :file :depth 0 : entry :entry-index index}))

(fn row-cache [state]
  (when (not state.row_cache)
    (set state.row_cache {}))
  state.row_cache)

(fn cached-rows [state key build]
  (let [cache (row-cache state)
        rows (. cache key)]
    (if rows
        rows
        (let [rows (build)]
          (tset cache key rows)
          rows))))

(fn invalidate-rows [state]
  (set state.row_cache nil)
  state)

(fn tree-rows [state]
  (cached-rows state :tree #(tree.rows state.entries)))

(fn cached-flat-rows [state]
  (cached-rows state :flat #(flat-rows state.entries)))

(fn rows [state]
  (if (= state.view_mode :tree)
      (tree-rows state)
      (cached-flat-rows state)))

(fn selected-tree-row [state]
  (tree.row-at (tree-rows state) state.tree_selected_row))

(fn selected-entry [state]
  (if (= state.view_mode :tree)
      (let [row (selected-tree-row state)]
        (and row (= row.type :file) row.entry))
      (. state.entries state.selected)))

(fn selected-context [state]
  (if (= state.view_mode :tree)
      (let [row (selected-tree-row state)]
        {: row :entry (if (and row (= row.type :file)) row.entry)})
      {:row nil :entry (. state.entries state.selected)}))

(fn selected-row-index [state ?rows]
  (if (= state.view_mode :tree)
      (or state.tree_selected_row
          (tree.selected-row (or ?rows (tree-rows state)) state.selected))
      state.selected))

(fn selected-row? [state row row-index]
  (if (= state.view_mode :tree)
      (= row-index state.tree_selected_row)
      (= row.entry-index state.selected)))

(fn cursor-position [state]
  (selected-row-index state))

(fn set-file [state selected]
  (let [before state.selected]
    (set state.selected selected)
    (when (selection-plan.changed? before state.selected)
      (preview.reset-scroll state))))

(fn set-tree-row [state row-index]
  (let [rows (tree-rows state)
        before state.tree_selected_row
        row-index (tree.move-row rows 1 (- row-index 1))]
    (set state.tree_selected_row row-index)
    (let [entry-index (tree.entry-index-at-row rows row-index)]
      (when entry-index
        (set state.selected entry-index)))
    (when (selection-plan.changed? before state.tree_selected_row)
      (preview.reset-scroll state))))

(fn move [state delta]
  (if (= state.view_mode :tree)
      (set-tree-row state
                    (tree.move-row (tree-rows state) state.tree_selected_row
                                   delta))
      (set-file state (selection-plan.flat-index state.entries state.selected
                                                 delta))))

(fn top [state]
  (if (= state.view_mode :tree)
      (set-tree-row state (tree.first-row (tree-rows state)))
      (set-file state 1)))

(fn bottom [state]
  (if (= state.view_mode :tree)
      (set-tree-row state (tree.last-row (tree-rows state)))
      (set-file state (length state.entries))))

(fn set-match [state found]
  (when found
    (if found.tree-row
        (set-tree-row state found.tree-row)
        (set-file state found.entry))))

(fn set-initial-tree-row [state]
  (set state.tree_selected_row
       (tree.selected-row (tree-rows state) state.selected)))

(fn toggle-mode [state]
  (if (= state.view_mode :tree)
      (do
        (let [entry-index (tree.entry-index-at-row (tree-rows state)
                                                   state.tree_selected_row)]
          (when entry-index
            (set state.selected entry-index)))
        (set state.view_mode :flat))
      (do
        (set state.view_mode :tree)
        (set-initial-tree-row state))))

{: bottom
 : cursor-position
 : flat-rows
 : invalidate-rows
 : move
 : rows
 : selected-entry
 : selected-context
 : selected-row?
 : selected-row-index
 : selected-tree-row
 : set-file
 : set-initial-tree-row
 : set-match
 : set-tree-row
 : toggle-mode
 : top
 : tree-rows}
