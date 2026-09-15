(local faith (require :faith))
(local matcher (require :app.search-match))
(local preview-key (require :preview.key))

(fn entry [status path]
  {: status :kind (status:sub 1 1) : path :reviewed false})

(fn test-collects-flat-entry-matches []
  (let [state {:view_mode :flat
               :revision "HEAD"
               :preview_cache {}
               :preview_line_refs_cache {}
               :entries [(entry "M" "src/app.fnl")
                         (entry "M" "test/app-test.fnl")]}]
    (faith.= [{:entry 1} {:entry 2}] (matcher.collect-matches state "app"))
    (faith.= [] (matcher.collect-matches state "missing"))))

(fn test-collects-tree-folder-and-file-matches []
  (let [state {:view_mode :tree
               :revision "HEAD"
               :preview_cache {}
               :preview_line_refs_cache {}
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

(fn test-tree-matches-pasted-path []
  (let [state {:view_mode :tree
               :revision "HEAD"
               :preview_cache {}
               :preview_line_refs_cache {}
               :entries [(entry "M" "src/app/view.fnl")
                         (entry "M" "test/app-test.fnl")]
               :selected 1
               :tree_selected_row 1}]
    (faith.= [{:entry 1 :tree-row 2}]
             (matcher.collect-matches state "src/app/view.fnl"))
    (faith.= [{:entry nil :tree-row 1} {:entry 1 :tree-row 2}]
             (matcher.collect-matches state "src/app"))))

(fn test-tree-matches-folder-path-with-trailing-slash []
  (let [state {:view_mode :tree
               :revision "HEAD"
               :preview_cache {}
               :preview_line_refs_cache {}
               :entries [(entry "M" "src/app/view.fnl")
                         (entry "M" "src/lib/util.fnl")]
               :selected 1
               :tree_selected_row 1}]
    (faith.= [{:entry nil :tree-row 2} {:entry 1 :tree-row 3}]
             (matcher.collect-matches state "src/app/"))))

(fn test-tree-path-query-does-not-widen-label-search []
  (let [state {:view_mode :tree
               :revision "HEAD"
               :preview_cache {}
               :preview_line_refs_cache {}
               :entries [(entry "M" "src/app/view.fnl")
                         (entry "M" "test/app-test.fnl")]
               :selected 1
               :tree_selected_row 1}]
    (faith.= [{:entry nil :tree-row 1} {:entry 2 :tree-row 4}]
             (matcher.collect-matches state "app"))))

(fn cached [state index lines]
  (let [key (preview-key.for-entry "HEAD" (. state.entries index))]
    (tset state.preview_cache key lines)
    (tset state.preview_line_refs_cache key
          (icollect [no (ipairs lines)]
            {:side :new : no :changed? true}))))

(fn test-every-cached-file-contributes-its-lines []
  (let [state {:view_mode :flat
               :revision "HEAD"
               :entries [(entry "M" "a-roll.rb")
                         (entry "M" "b-other.rb")
                         (entry "M" "c-roll.rb")]
               :preview_cache {}
               :preview_line_refs_cache {}}]
    (cached state 1 ["roll one" "x" "roll two"])
    (cached state 2 ["b has roll"])
    (faith.= [{:entry 1}
              {:row 1 :line 1}
              {:row 1 :line 3}
              {:row 2 :line 1}
              {:entry 3}] (matcher.collect-matches state "roll"))
    (cached state 3 ["a roll"])
    (faith.= 6 (length (matcher.collect-matches state "roll")))))

(fn test-tree-lines-use-the-tree-row []
  (let [state {:view_mode :tree
               :revision "HEAD"
               :entries [(entry "M" "src/app.fnl")
                         (entry "M" "test/app-test.fnl")]
               :selected 1
               :tree_selected_row 2
               :preview_cache {}
               :preview_line_refs_cache {}}]
    (cached state 2 ["app line"])
    (faith.= [{:entry 1 :tree-row 2} {:entry 2 :tree-row 4} {:row 4 :line 1}]
             (matcher.collect-matches state "app"))))

{: test-collects-flat-entry-matches
 : test-every-cached-file-contributes-its-lines
 : test-tree-lines-use-the-tree-row
 : test-collects-tree-folder-and-file-matches
 : test-tree-label-uses-folder-name-or-file-name
 : test-tree-matches-pasted-path
 : test-tree-matches-folder-path-with-trailing-slash
 : test-tree-path-query-does-not-widen-label-search}
