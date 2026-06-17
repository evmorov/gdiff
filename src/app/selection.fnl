(local preview (require :preview.core))
(local tree (require :app.tree))
(local math-util (require :util.math))

(fn flat-rows [entries]
  (icollect [index entry (ipairs entries)]
    {:type :file :depth 0 :entry entry :entry-index index}))

(fn tree-rows [state]
  (tree.rows state.entries))

(fn rows [state]
  (if (= state.view_mode :tree)
      (tree-rows state)
      (flat-rows state.entries)))

(fn selected-tree-row [state]
  (tree.row-at (tree-rows state) state.tree_selected_row))

(fn selected-entry [state]
  (if (= state.view_mode :tree)
      (let [row (selected-tree-row state)]
        (and row (= row.type :file) row.entry))
      (. state.entries state.selected)))

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
    (when (not (= before state.selected))
      (preview.reset-scroll state))))

(fn set-tree-row [state row-index]
  (let [rows (tree-rows state)
        before state.tree_selected_row
        row-index (tree.move-row rows 1 (- row-index 1))]
    (set state.tree_selected_row row-index)
    (let [entry-index (tree.entry-index-at-row rows row-index)]
      (when entry-index
        (set state.selected entry-index)))
    (when (not (= before state.tree_selected_row))
      (preview.reset-scroll state))))

(fn move [state delta]
  (if (= state.view_mode :tree)
      (set-tree-row state
                    (tree.move-row (tree-rows state) state.tree_selected_row
                                   delta))
      (set-file state
                (if (= (length state.entries) 0)
                    1
                    (math-util.clamp (+ state.selected delta) 1
                                     (length state.entries))))))

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
 : move
 : rows
 : selected-entry
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
