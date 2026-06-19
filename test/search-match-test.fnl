(local faith (require :faith))
(local matcher (require :app.search-match))

(fn entry [status path]
  {: status :kind (status:sub 1 1) : path :reviewed false})

(fn test-collects-flat-entry-matches []
  (let [state {:view_mode :flat
               :entries [(entry "M" "src/app.fnl")
                         (entry "M" "test/app-test.fnl")]}]
    (faith.= [{:entry 1} {:entry 2}] (matcher.collect-matches state "app"))
    (faith.= [] (matcher.collect-matches state "missing"))))

(fn test-collects-tree-folder-and-file-matches []
  (let [state {:view_mode :tree
               :entries [(entry "M" "src/app.fnl")
                         (entry "M" "test/app-test.fnl")]
               :selected 1
               :tree_selected_row 1}]
    (faith.= [{:entry nil :tree-row 1}] (matcher.collect-matches state "src"))
    (faith.= [{:entry 1 :tree-row 2}] (matcher.collect-matches state "app.fnl"))))

(fn test-tree-label-uses-folder-name-or-file-name []
  (faith.= "src/" (matcher.tree-label {:type :folder :name "src/"}))
  (faith.= "app.fnl"
           (matcher.tree-label {:type :file
                                :name "app.fnl"
                                :entry (entry "M" "src/app.fnl")})))

{: test-collects-flat-entry-matches
 : test-collects-tree-folder-and-file-matches
 : test-tree-label-uses-folder-name-or-file-name}
