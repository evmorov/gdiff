(local faith (require :faith))
(local selection (require :app.selection))

(fn entry [path]
  {:status "M" :kind "M" :path path :reviewed false})

(fn test-selected_context_returns_tree_folder_row_without_entry []
  (let [state {:entries [(entry "src/a.rb")]
               :view_mode :tree
               :selected 1
               :tree_selected_row 1}
        context (selection.selected-context state)]
    (faith.= :folder context.row.type)
    (faith.= nil context.entry)))

(fn test-selected_context_returns_tree_file_entry []
  (let [selected (entry "src/a.rb")
        state {:entries [selected]
               :view_mode :tree
               :selected 1
               :tree_selected_row 2}
        context (selection.selected-context state)]
    (faith.= :file context.row.type)
    (faith.= selected context.entry)))

(fn test-selected_context_returns_flat_entry []
  (let [selected (entry "a.rb")
        state {:entries [selected] :view_mode :flat :selected 1}
        context (selection.selected-context state)]
    (faith.= nil context.row)
    (faith.= selected context.entry)))

{: test-selected_context_returns_flat_entry
 : test-selected_context_returns_tree_file_entry
 : test-selected_context_returns_tree_folder_row_without_entry}
