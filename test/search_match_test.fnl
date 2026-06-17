(local faith (require :faith))
(local matcher (require :app.search_match))

(fn entry [status path]
  {:status status :kind (status:sub 1 1) :path path :reviewed false})

(fn test-collects_flat_entry_matches []
  (let [state {:view_mode :flat
               :entries [(entry "M" "src/app.fnl")
                         (entry "M" "test/app-test.fnl")]}]
    (faith.= [{:entry 1} {:entry 2}] (matcher.collect-matches state "app"))
    (faith.= [] (matcher.collect-matches state "missing"))))

(fn test-collects_tree_folder_and_file_matches []
  (let [state {:view_mode :tree
               :entries [(entry "M" "src/app.fnl")
                         (entry "M" "test/app-test.fnl")]
               :selected 1
               :tree_selected_row 1}]
    (faith.= [{:entry nil :tree-row 1}] (matcher.collect-matches state "src"))
    (faith.= [{:entry 1 :tree-row 2}] (matcher.collect-matches state "app.fnl"))))

(fn test-tree-label_uses_folder_name_or_file_name []
  (faith.= "src/" (matcher.tree-label {:type :folder :name "src/"}))
  (faith.= "app.fnl"
           (matcher.tree-label {:type :file
                                :name "app.fnl"
                                :entry (entry "M" "src/app.fnl")})))

{: test-collects_flat_entry_matches
 : test-collects_tree_folder_and_file_matches
 : test-tree-label_uses_folder_name_or_file_name}
