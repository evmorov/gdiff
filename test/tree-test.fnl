(local faith (require :faith))
(local tree (require :app.tree))

(fn entry [status path ?old-path]
  {:status status
   :kind (status:sub 1 1)
   :path path
   :old_path ?old-path
   :reviewed false})

(fn simple-row [row]
  (if (= row.type :folder)
      {:type row.type :depth row.depth :name row.name}
      {:type row.type
       :depth row.depth
       :name row.name
       :entry-index row.entry-index}))

(fn simple-rows [rows]
  (icollect [_ row (ipairs rows)]
    (simple-row row)))

(fn test-tree_rows_collapse_single_directory_chains []
  (let [rows (tree.rows [(entry "A" "script/shorthand_branch.sh")
                         (entry "M"
                                "spec/lib/epoxy/version_branch_validation_spec.rb")
                         (entry "M" "spec/lib/direct_spec.rb")
                         (entry "M"
                                "spec/lib/tasks/helpers/commit_validator_spec.rb")])]
    (faith.= [{:type :folder :depth 0 :name "script/"}
              {:type :file :depth 1 :name "shorthand_branch.sh" :entry-index 1}
              {:type :folder :depth 0 :name "spec/lib/"}
              {:type :file :depth 1 :name "direct_spec.rb" :entry-index 3}
              {:type :folder :depth 1 :name "epoxy/"}
              {:type :file
               :depth 2
               :name "version_branch_validation_spec.rb"
               :entry-index 2}
              {:type :folder :depth 1 :name "tasks/helpers/"}
              {:type :file
               :depth 2
               :name "commit_validator_spec.rb"
               :entry-index 4}] (simple-rows rows))))

(fn test-selected-row_maps_entry_index_to_tree_row []
  (let [rows (tree.rows [(entry "A" "script/a.sh")
                         (entry "M" "spec/lib/a_spec.rb")])]
    (faith.= 2 (tree.selected-row rows 1))
    (faith.= 4 (tree.selected-row rows 2))))

(fn test-tree_selection_moves_in_rendered_row_order []
  (let [entries [(entry "M" "z.rb")
                 (entry "M" "script/a.sh")
                 (entry "M" "spec/b_spec.rb")]
        rows (tree.rows entries)]
    (faith.= 1 (tree.first-row rows))
    (faith.= 5 (tree.last-row rows))
    (faith.= 2 (tree.move-row rows 1 1))
    (faith.= 5 (tree.move-row rows 4 1))
    (faith.= 4 (tree.move-row rows 5 -1))
    (faith.= 1 (tree.entry-index-at-row rows 1))
    (faith.= nil (tree.entry-index-at-row rows 2))))

{: test-selected-row_maps_entry_index_to_tree_row
 : test-tree_selection_moves_in_rendered_row_order
 : test-tree_rows_collapse_single_directory_chains}
