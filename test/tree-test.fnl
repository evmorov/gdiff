(local faith (require :faith))
(local tree (require :app.tree))

(fn entry [status path ?old-path]
  {: status :kind (status:sub 1 1) : path :old_path ?old-path :reviewed false})

(fn simple-row [row]
  (if (= row.type :folder)
      {:type row.type :depth row.depth :name row.name :path row.path}
      {:type row.type
       :depth row.depth
       :name row.name
       :entry-index row.entry-index}))

(fn simple-rows [rows]
  (icollect [_ row (ipairs rows)]
    (simple-row row)))

(fn test-tree-rows-collapse-single-directory-chains []
  (let [rows (tree.rows [(entry "A" "script/shorthand_branch.sh")
                         (entry "M"
                                "spec/lib/epoxy/version_branch_validation_spec.rb")
                         (entry "M" "spec/lib/direct_spec.rb")
                         (entry "M"
                                "spec/lib/tasks/helpers/commit_validator_spec.rb")])]
    (faith.= [{:type :folder :depth 0 :name "script/" :path "script"}
              {:type :file :depth 1 :name "shorthand_branch.sh" :entry-index 1}
              {:type :folder :depth 0 :name "spec/lib/" :path "spec/lib"}
              {:type :file :depth 1 :name "direct_spec.rb" :entry-index 3}
              {:type :folder :depth 1 :name "epoxy/" :path "spec/lib/epoxy"}
              {:type :file
               :depth 2
               :name "version_branch_validation_spec.rb"
               :entry-index 2}
              {:type :folder
               :depth 1
               :name "tasks/helpers/"
               :path "spec/lib/tasks/helpers"}
              {:type :file
               :depth 2
               :name "commit_validator_spec.rb"
               :entry-index 4}] (simple-rows rows))))

(fn test-selected-row-maps-entry-index-to-tree-row []
  (let [rows (tree.rows [(entry "A" "script/a.sh")
                         (entry "M" "spec/lib/a_spec.rb")])]
    (faith.= 2 (tree.selected-row rows 1))
    (faith.= 4 (tree.selected-row rows 2))))

(fn test-tree-selection-moves-in-rendered-row-order []
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

(fn test-folder-rows-keep-descendant-entries []
  (let [first (entry "M" "src/a.rb")
        second (entry "A" "src/nested/b.rb")
        rows (tree.rows [first second])
        folder (. rows 1)]
    (faith.= "src/" folder.name)
    (faith.= [first second] folder.entries)))

(fn test-expanded-folder-lists-files-and-folders []
  (let [rows (tree.rows [(entry "M" "src/a.rb")]
                        {:src [{:name "a.rb" :folder? false}
                               {:name "b.rb" :folder? false}
                               {:name "sub" :folder? true}]})
        b-row (. rows 3)
        sub-row (. rows 4)]
    (faith.= 4 (length rows))
    (faith.= {:type :file :depth 1 :name "b.rb"} (simple-row b-row))
    (faith.= true b-row.unchanged)
    (faith.= "src/b.rb" b-row.path)
    (faith.= {:type :folder :depth 1 :name "sub/" :path "src/sub"}
             (simple-row sub-row))))

(fn test-expanded-folder-keeps-children-on-one-level []
  (let [rows (tree.rows [(entry "M" "src/a.rb")]
                        {:src [{:name "a.rb" :folder? false}
                               {:name "b.rb" :folder? false}
                               {:name "sub" :folder? true}]})
        changed (. rows 2)
        unchanged (. rows 3)
        folder (. rows 4)]
    ;; Changed file, unchanged file, and listed folder all share one indent.
    (faith.= 1 changed.depth)
    (faith.= 1 unchanged.depth)
    (faith.= 1 folder.depth)
    (faith.= 1 changed.entry-index)
    (faith.= nil unchanged.entry-index)))

(fn test-expanded-nested-folder-lists-children []
  (let [rows (tree.rows [(entry "M" "src/a.rb")]
                        {:src [{:name "sub" :folder? true}]
                         "src/sub" [{:name "c.rb" :folder? false}]})
        sub-row (. rows 3)
        c-row (. rows 4)]
    (faith.= true sub-row.expanded)
    (faith.= {:type :file :depth 2 :name "c.rb"} (simple-row c-row))
    (faith.= "src/sub/c.rb" c-row.path)))

{: test-selected-row-maps-entry-index-to-tree-row
 : test-tree-selection-moves-in-rendered-row-order
 : test-folder-rows-keep-descendant-entries
 : test-expanded-folder-lists-files-and-folders
 : test-expanded-folder-keeps-children-on-one-level
 : test-expanded-nested-folder-lists-children
 : test-tree-rows-collapse-single-directory-chains}
