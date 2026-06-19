(local faith (require :faith))
(local selection (require :app.selection))
(local tree (require :app.tree))

(fn entry [path]
  {:status "M" :kind "M" : path :reviewed false})

(fn state [entries]
  {: entries :view_mode :tree :selected 1 :tree_selected_row 1})

(fn test-tree-rows-are-cached-until-invalidated []
  (let [state (state [(entry "src/a.rb")])
        calls []
        old-rows tree.rows]
    (set tree.rows (fn [entries]
                     (table.insert calls entries)
                     (old-rows entries)))
    (faith.= 2 (length (selection.tree-rows state)))
    (faith.= 2 (length (selection.tree-rows state)))
    (faith.= 1 (length calls))
    (selection.invalidate-rows state)
    (faith.= 2 (length (selection.tree-rows state)))
    (set tree.rows old-rows)
    (faith.= 2 (length calls))))

(fn test-flat-rows-are-cached-until-invalidated []
  (let [state {:entries [(entry "a.rb")] :view_mode :flat :selected 1}
        first (selection.rows state)
        second (selection.rows state)]
    (faith.= first second)
    (selection.invalidate-rows state)
    (set state.entries [(entry "a.rb") (entry "b.rb")])
    (faith.= 2 (length (selection.rows state)))))

(fn test-selected-row-index-uses-cached-tree-selection-without-scan []
  (let [state (state [(entry "src/a.rb")])
        calls []
        old-selected-row tree.selected-row]
    (set tree.selected-row (fn [...]
                             (table.insert calls true)
                             (old-selected-row ...)))
    (faith.= 1 (selection.selected-row-index state))
    (set tree.selected-row old-selected-row)
    (faith.= 0 (length calls))))

{: test-flat-rows-are-cached-until-invalidated
 : test-selected-row-index-uses-cached-tree-selection-without-scan
 : test-tree-rows-are-cached-until-invalidated}
