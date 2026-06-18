(local faith (require :faith))
(local folder (require :preview.folder))
(local sys (require :platform.core))
(local t (require :test-helper))

(fn entry [kind path]
  {:kind kind :status kind :path path :reviewed false})

(fn state [entries]
  {:entries entries :folder_preview_cache {}})

(fn test-render-lines_marks_changed_children_and_deleted_files []
  (let [state (state [(entry "A" "src/added.rb")
                      (entry "M" "src/updated.rb")
                      (entry "D" "src/deleted.rb")])
        row {:path "src"}
        record {:ok? true
                :output (table.concat ["total 8"
                                       "drwxr-xr-x  3 u  g  96 Jan  1 00:00 ."
                                       "drwxr-xr-x  8 u  g 256 Jan  1 00:00 .."
                                       "-rw-r--r--  1 u  g  1 Jan  1 00:00 added.rb"
                                       "-rw-r--r--  1 u  g  1 Jan  1 00:00 updated.rb"
                                       "-rw-r--r--  1 u  g  1 Jan  1 00:00 unchanged.rb"]
                                      "\n")}]
    (faith.= (table.concat ["[M] src/"
                            ""
                            "[A] added.rb"
                            "[M] updated.rb"
                            "[D] deleted.rb"
                            "    unchanged.rb"] "\n")
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines_marks_child_directories_with_descendant_changes []
  (let [state (state [(entry "M" "src/nested/changed.rb")])
        row {:path "src"}
        record {:ok? true
                :output "total 0\ndrwxr-xr-x  2 u  g  64 Jan  1 00:00 nested\n"}]
    (faith.= "[M] src/\n\n[M] nested/"
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines_does_not_mark_directory_deleted_for_deleted_descendant []
  (let [state (state [(entry "D" "src/nested/deleted.rb")])
        row {:path "src"}
        record {:ok? true
                :output "total 0\ndrwxr-xr-x  2 u  g  64 Jan  1 00:00 nested\n"}]
    (faith.= "[D] src/\n\n[M] nested/"
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines_synthesizes_deleted_folder_without_ls_error []
  (let [state (state [(entry "D" "src/deleted.rb") (entry "D" "src/old.rb")])
        row {:path "src"}
        record {:ok? false :output "ls: src: No such file or directory"}]
    (faith.= (table.concat ["[D] src/" "" "[D] deleted.rb" "[D] old.rb"] "\n")
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines_synthesizes_missing_child_folder_as_deleted []
  (let [state (state [(entry "D" "src/nested/deleted.rb")])
        row {:path "src"}
        record {:ok? false :output "ls: src: No such file or directory"}]
    (faith.= "[D] src/\n\n[D] nested/"
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines_adds_missing_deleted_child_folder_to_live_parent []
  (let [state (state [(entry "D" "src/nested/deleted.rb")])
        row {:path "src"}
        record {:ok? true :output "total 0\n"}]
    (faith.= "[D] src/\n\n[D] nested/"
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines_sorts_like_left_tree []
  (let [state (state [(entry "M" "src/b.rb")
                      (entry "M" "src/nested/changed.rb")
                      (entry "A" "src/a.rb")])
        row {:path "src"}
        record {:ok? true
                :output (table.concat ["total 0"
                                       "drwxr-xr-x  2 u  g  64 Jan  1 00:00 nested"
                                       "-rw-r--r--  1 u  g   1 Jan  1 00:00 z.rb"
                                       "-rw-r--r--  1 u  g   1 Jan  1 00:00 a.rb"
                                       "-rw-r--r--  1 u  g   1 Jan  1 00:00 b.rb"]
                                      "\n")}]
    (faith.= (table.concat ["[M] src/"
                            ""
                            "[M] b.rb"
                            "[A] a.rb"
                            "    z.rb"
                            "[M] nested/"] "\n")
             (t.text (folder.render-lines state row record)))))

(fn test-lines_caches_raw_listing_but_applies_current_statuses []
  (let [state (state [])
        row {:path "src"}
        calls []
        old-read sys.read-command]
    (set sys.read-command (fn [cmd]
                            (table.insert calls cmd)
                            (values "total 0\n-rw-r--r--  1 u  g  1 Jan  1 00:00 a.rb\n"
                                    true "exit" 0)))
    (faith.= "    src/\n\n    a.rb" (t.text (folder.lines state row)))
    (set state.entries [(entry "M" "src/a.rb")])
    (faith.= "[M] src/\n\n[M] a.rb" (t.text (folder.lines state row)))
    (set sys.read-command old-read)
    (faith.= 1 (length calls))
    (faith.= "ls -la 'src' 2>&1" (. calls 1))))

{: test-lines_caches_raw_listing_but_applies_current_statuses
 : test-render-lines_does_not_mark_directory_deleted_for_deleted_descendant
 : test-render-lines_marks_changed_children_and_deleted_files
 : test-render-lines_marks_child_directories_with_descendant_changes
 : test-render-lines_synthesizes_deleted_folder_without_ls_error
 : test-render-lines_adds_missing_deleted_child_folder_to_live_parent
 : test-render-lines_synthesizes_missing_child_folder_as_deleted
 : test-render-lines_sorts_like_left_tree}
