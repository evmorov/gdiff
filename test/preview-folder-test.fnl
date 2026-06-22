(local faith (require :faith))
(local folder (require :preview.folder))
(local sys (require :platform.core))
(local t (require :test-helper))

(fn entry [kind path]
  {: kind :status kind : path :reviewed false})

(fn unstaged-entry [kind path]
  {: kind :status kind : path :reviewed false :unstaged? true})

(fn state [entries]
  {: entries :folder_preview_cache {}})

(fn test-render-lines-marks-changed-children-and-deleted-files []
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
                            "────────"
                            "[A] added.rb"
                            "[M] updated.rb"
                            "[D] deleted.rb"
                            "    unchanged.rb"] "\n")
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines-marks-child-directories-with-descendant-changes []
  (let [state (state [(entry "M" "src/nested/changed.rb")])
        row {:path "src"}
        record {:ok? true
                :output "total 0\ndrwxr-xr-x  2 u  g  64 Jan  1 00:00 nested\n"}]
    (faith.= "[M] src/\n────────\n[M] nested/"
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines-does-not-mark-directory-deleted-for-deleted-descendant []
  (let [state (state [(entry "D" "src/nested/deleted.rb")])
        row {:path "src"}
        record {:ok? true
                :output "total 0\ndrwxr-xr-x  2 u  g  64 Jan  1 00:00 nested\n"}]
    (faith.= "[D] src/\n────────\n[M] nested/"
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines-synthesizes-deleted-folder-without-ls-error []
  (let [state (state [(entry "D" "src/deleted.rb") (entry "D" "src/old.rb")])
        row {:path "src"}
        record {:ok? false :output "ls: src: No such file or directory"}]
    (faith.= (table.concat ["[D] src/"
                            "────────"
                            "[D] deleted.rb"
                            "[D] old.rb"] "\n")
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines-synthesizes-missing-child-folder-as-deleted []
  (let [state (state [(entry "D" "src/nested/deleted.rb")])
        row {:path "src"}
        record {:ok? false :output "ls: src: No such file or directory"}]
    (faith.= "[D] src/\n────────\n[D] nested/"
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines-adds-missing-deleted-child-folder-to-live-parent []
  (let [state (state [(entry "D" "src/nested/deleted.rb")])
        row {:path "src"}
        record {:ok? true :output "total 0\n"}]
    (faith.= "[D] src/\n────────\n[D] nested/"
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines-sorts-like-left-tree []
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
                            "────────"
                            "[M] b.rb"
                            "[A] a.rb"
                            "    z.rb"
                            "[M] nested/"] "\n")
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines-uses-row-descendants-when-available []
  (let [state (state [(entry "M" "other/noise.rb")
                      (entry "D" "src/unrelated-from-state.rb")])
        row {:path "src" :entries [(entry "A" "src/kept.rb")]}
        record {:ok? true
                :output (table.concat ["total 0"
                                       "-rw-r--r--  1 u  g   1 Jan  1 00:00 kept.rb"
                                       "-rw-r--r--  1 u  g   1 Jan  1 00:00 unrelated-from-state.rb"]
                                      "\n")}]
    (faith.= (table.concat ["[A] src/"
                            "────────"
                            "[A] kept.rb"
                            "    unrelated-from-state.rb"]
                           "\n")
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines-shows-unstaged-leaf-but-real-folder-kind []
  (let [state (state [(unstaged-entry "M" "src/tardis.rb")])
        row {:path "src"}
        record {:ok? true
                :output (table.concat ["total 0"
                                       "-rw-r--r--  1 u  g  1 Jan  1 00:00 tardis.rb"
                                       "-rw-r--r--  1 u  g  1 Jan  1 00:00 other.rb"]
                                      "\n")}]
    (faith.= (table.concat ["[M] src/"
                            "────────"
                            "[?] tardis.rb"
                            "    other.rb"] "\n")
             (t.text (folder.render-lines state row record)))))

(fn test-render-lines-keeps-real-kind-for-subfolder-with-unstaged-child []
  (let [state (state [(unstaged-entry "M" "src/nested/changed.rb")])
        row {:path "src"}
        record {:ok? true
                :output "total 0\ndrwxr-xr-x  2 u  g  64 Jan  1 00:00 nested\n"}]
    (faith.= "[M] src/\n────────\n[M] nested/"
             (t.text (folder.render-lines state row record)))))

(fn test-parsed-listing-returns-fresh-copies-from-cached-parse []
  (let [record {:ok? true
                :output "total 0\n-rw-r--r--  1 u  g  1 Jan  1 00:00 a.rb\n"}
        (entries seen) (folder.parsed-listing record)]
    (set (. entries 1 :name) "changed.rb")
    (tset seen "a.rb" nil)
    (let [(again again-seen) (folder.parsed-listing record)]
      (faith.= "a.rb" (. again 1 :name))
      (faith.= true (. again-seen "a.rb")))))

(fn test-folder-plan-is-cached-on-rows-with-descendants []
  (let [state (state [(entry "D" "src/from-state.rb")])
        row {:path "src" :entries [(entry "A" "src/from-row.rb")]}
        plan (folder.folder-plan-for state row)]
    (faith.= plan row.folder-plan)
    (faith.= "A" plan.folder-kind)
    (set state.entries [(entry "M" "src/changed-state.rb")])
    (faith.= plan (folder.folder-plan-for state row))
    (faith.= "A" (. plan.statuses "from-row.rb"))
    (faith.= nil (. plan.statuses "changed-state.rb"))))

(fn test-folder-plan-without-row-descendants-tracks-state-entries []
  (let [state (state [(entry "A" "src/a.rb")])
        row {:path "src"}]
    (faith.= "A" (. (folder.folder-plan-for state row) :statuses "a.rb"))
    (set state.entries [(entry "M" "src/a.rb")])
    (faith.= "M" (. (folder.folder-plan-for state row) :statuses "a.rb"))))

(fn test-lines-caches-raw-listing-but-applies-current-statuses []
  (let [state (state [])
        row {:path "src"}
        calls []
        old-read sys.read-command]
    (set sys.read-command (fn [cmd]
                            (table.insert calls cmd)
                            (values "total 0\n-rw-r--r--  1 u  g  1 Jan  1 00:00 a.rb\n"
                                    true "exit" 0)))
    (faith.= "    src/\n────────\n    a.rb"
             (t.text (folder.lines state row)))
    (set state.entries [(entry "M" "src/a.rb")])
    (faith.= "[M] src/\n────────\n[M] a.rb"
             (t.text (folder.lines state row)))
    (set sys.read-command old-read)
    (faith.= 1 (length calls))
    (faith.= "ls -la 'src' 2>&1" (. calls 1))))

{: test-lines-caches-raw-listing-but-applies-current-statuses
 : test-render-lines-does-not-mark-directory-deleted-for-deleted-descendant
 : test-render-lines-marks-changed-children-and-deleted-files
 : test-render-lines-marks-child-directories-with-descendant-changes
 : test-render-lines-synthesizes-deleted-folder-without-ls-error
 : test-render-lines-adds-missing-deleted-child-folder-to-live-parent
 : test-render-lines-synthesizes-missing-child-folder-as-deleted
 : test-render-lines-sorts-like-left-tree
 : test-render-lines-shows-unstaged-leaf-but-real-folder-kind
 : test-render-lines-keeps-real-kind-for-subfolder-with-unstaged-child
 : test-folder-plan-is-cached-on-rows-with-descendants
 : test-folder-plan-without-row-descendants-tracks-state-entries
 : test-parsed-listing-returns-fresh-copies-from-cached-parse
 : test-render-lines-uses-row-descendants-when-available}
