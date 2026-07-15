(local app (require :app.core))
(local browser (require :platform.browser))
(local editor (require :platform.editor))
(local faith (require :faith))
(local fennel (require :fennel))
(local git (require :git.core))
(local preview-key (require :preview.key))
(local reviews (require :storage.reviews))
(local selection (require :app.selection))
(local sys (require :platform.core))
(local t (require :test-helper))
(local tui (require :tui.core))
(local update (require :app.update))

(fn entry [status path ?old-path]
  {: status :kind (status:sub 1 1) : path :old_path ?old-path :reviewed false})

(fn state [entries]
  (let [state (app.new-state "HEAD" entries {:version 1 :reviews {}} "scope"
                             "src")]
    (set state.sync.next_at (+ (os.time) 999))
    state))

(fn flat-state [entries]
  (let [state (state entries)]
    (set state.view_mode :flat)
    (set state.tree_selected_row nil)
    state))

(fn plain-row-text [row]
  (tui.strip-ansi row.text))

(fn folder-row-index [state path]
  (var found nil)
  (each [index row (ipairs (selection.rows state))]
    (when (and (not found) (= row.type :folder) (= row.path path))
      (set found index)))
  found)

(fn select-folder [state path]
  (let [index (folder-row-index state path)]
    (faith.is index (.. "missing folder row: " path))
    (set state.tree_selected_row index)))

(fn file-row-index [state name]
  (accumulate [found nil index row (ipairs (selection.rows state)) &until found]
    (when (and (= row.type :file) (= row.name name)) index)))

(fn select-file [state name]
  (let [index (file-row-index state name)]
    (faith.is index (.. "missing file row: " name))
    (set state.tree_selected_row index)))

(fn setup-real-folder-preview-repo []
  (t.init-repo)
  (t.mkdir "lib/tardis/docker/views")
  (t.mkdir "lib/tardis/docker/workers")
  (t.write-file "lib/tardis/docker/views/index.rb" "view\n")
  (t.write-file "lib/tardis/docker/workers/app.rb" "app\n")
  (t.write-file "lib/tardis/docker/workers/sidekiq.rb" "sidekiq\n")
  (t.write-file "lib/tardis/docker/web.rb" "web\n")
  (t.write-file "lib/tardis/docker/api.rb" "api\n")
  (t.commit-all "initial")
  (t.sh "rm -rf lib/tardis/docker/views")
  (t.sh "rm -rf lib/tardis/docker/workers")
  (t.sh "rm lib/tardis/docker/web.rb")
  (t.write-file "lib/tardis/docker/api.rb" "api\nchanged\n"))

(fn real-preview-state []
  (let [(entries err) (git.diff-entries "HEAD")]
    (faith.= nil err)
    (state entries)))

(fn test-lowercase-a-toggles-all-reviewed-and-uppercase-a-does-nothing []
  (let [state (state [(entry "M" "a.rb") (entry "A" "b.rb")])]
    (faith.is (app.handle-key state {} "a"))
    (faith.= 1 state.selected)
    (faith.= {"a.rb" true "b.rb" true} (reviews.paths state.entries))
    (faith.is (app.handle-key state {} "A"))
    (faith.= {"a.rb" true "b.rb" true} (reviews.paths state.entries))
    (faith.is (app.handle-key state {} "a"))
    (faith.= {} (reviews.paths state.entries))))

(fn test-search-next-is-relative-to-current-cursor []
  (let [state (flat-state [(entry "M" "api/v1.rb")
                           (entry "M" "api/v2.rb")
                           (entry "M" "api/v3.rb")])]
    (app.handle-key state {} "/")
    (app.handle-key state {} "a")
    (app.handle-key state {} :enter)
    (faith.= 1 state.selected)
    (app.handle-key state {} "n")
    (faith.= 2 state.selected)
    (app.handle-key state {} "k")
    (faith.= 1 state.selected)
    (app.handle-key state {} "n")
    (faith.= 2 state.selected)))

(fn test-view-renders-renames-with-short-status []
  (let [state (flat-state [(entry "R" "spec/tardis/api/v2_spec.rb"
                                  "spec/tardis/api_spec.rb")])
        view (app.view state 10 100)]
    (faith.= "> [ ] [R] spec/tardis/api/v2_spec.rb <- spec/tardis/api_spec.rb"
             (plain-row-text (. view.body.left.rows 1)))))

(fn test-view-styles-reviewed-checkbox-brackets-as-muted []
  (let [state (flat-state [(entry "M" "a.rb")])
        first-entry (. state.entries 1)]
    (set first-entry.reviewed true)
    (let [view (app.view state 10 100)
          text (. (. view.body.left.rows 1) :text)]
      (faith.= "> [x] [M] a.rb" (tui.strip-ansi text))
      (when (text:find "\27" 1 true)
        (faith.is (text:find "\27[2m[" 1 true))
        (faith.is (text:find "\27[2m]" 1 true))))))

(fn test-backtick-toggles-tree-mode-without-clearing-search []
  (let [state (flat-state [(entry "A" "script/shorthand_branch.sh")
                           (entry "M"
                                  "spec/lib/epoxy/version_branch_validation_spec.rb")
                           (entry "M"
                                  "spec/lib/tasks/helpers/commit_validator_spec.rb")])]
    (app.handle-key state {} "/")
    (app.handle-key state {} "s")
    (faith.= true state.search.active?)
    (faith.is (app.handle-key state {} "`"))
    (faith.= :tree state.view_mode)
    (faith.= true state.search.active?)
    (faith.= "s" state.search.query)
    (faith.is (app.handle-key state {} "`"))
    (faith.= :flat state.view_mode)
    (faith.= true state.search.active?)
    (faith.= "s" state.search.query)))

(fn test-backtick-preserves-selected-file-with-search []
  (let [state (flat-state [(entry "M" "alpha/file.rb") (entry "M" "z.rb")])]
    (app.handle-key state {} "/")
    (app.handle-key state {} "a")
    (app.handle-key state {} :enter)
    (faith.= 1 state.selected)
    (app.handle-key state {} "j")
    (faith.= 2 state.selected)
    (faith.is (app.handle-key state {} "`"))
    (faith.= :tree state.view_mode)
    (faith.= 2 state.selected)
    (faith.= 1 state.tree_selected_row)
    (faith.is (app.handle-key state {} "`"))
    (faith.= :flat state.view_mode)
    (faith.= 2 state.selected)))

(fn test-tree-view-renders-collapsed-folders-and-file-rows []
  (let [state (state [(entry "A" "script/shorthand_branch.sh")
                      (entry "M"
                             "spec/lib/epoxy/version_branch_validation_spec.rb")
                      (entry "M"
                             "spec/lib/tasks/helpers/commit_validator_spec.rb")])]
    (let [view (app.view state 12 100)
          rows view.body.left.rows]
      (faith.= "  script/" (plain-row-text (. rows 1)))
      (faith.= "  script/" (. (. rows 1) :text))
      (faith.= ">   [ ] [A] shorthand_branch.sh" (plain-row-text (. rows 2)))
      (faith.= "  spec/lib/" (plain-row-text (. rows 3)))
      (faith.= "  spec/lib/" (. (. rows 3) :text))
      (faith.= "    epoxy/" (plain-row-text (. rows 4)))
      (faith.= "      [ ] [M] version_branch_validation_spec.rb"
               (plain-row-text (. rows 5)))
      (faith.= "    tasks/helpers/" (plain-row-text (. rows 6)))
      (faith.= "      [ ] [M] commit_validator_spec.rb"
               (plain-row-text (. rows 7))))))

(fn test-tree-mode-navigation-moves-between-folders-and-files []
  (let [state (state [(entry "M" "z.rb")
                      (entry "A" "script/shorthand_branch.sh")
                      (entry "M"
                             "spec/lib/epoxy/version_branch_validation_spec.rb")])]
    (faith.= 1 state.selected)
    (faith.= 1 state.tree_selected_row)
    (app.handle-key state {} "g")
    (app.handle-key state {} "g")
    (faith.= 1 state.tree_selected_row)
    (app.handle-key state {} "j")
    (faith.= 2 state.tree_selected_row)
    (let [view (app.view state 10 100)]
      (faith.is (. view.body.right.lines 1)))
    (app.handle-key state {} "j")
    (faith.= 3 state.tree_selected_row)
    (faith.= 2 state.selected)
    (app.handle-key state {} "k")
    (faith.= 2 state.tree_selected_row)
    (app.handle-key state {} "g")
    (app.handle-key state {} "g")
    (faith.= 1 state.tree_selected_row)
    (app.handle-key state {} "G")
    (faith.= 5 state.tree_selected_row)
    (faith.= 3 state.selected)))

(fn test-space-on-tree-folder-toggles-descendant-files []
  (let [state (state [(entry "A" "script/shorthand_branch.sh")
                      (entry "M"
                             "spec/lib/epoxy/version_branch_validation_spec.rb")
                      (entry "M"
                             "spec/lib/tasks/helpers/commit_validator_spec.rb")])]
    (faith.= 2 state.tree_selected_row)
    (app.handle-key state {} "j")
    (faith.= 3 state.tree_selected_row)
    (app.handle-key state {} " ")
    (faith.= {"spec/lib/epoxy/version_branch_validation_spec.rb" true
              "spec/lib/tasks/helpers/commit_validator_spec.rb" true}
             (reviews.paths state.entries))
    (app.handle-key state {} " ")
    (faith.= {} (reviews.paths state.entries))))

(fn test-open-on-tree-folder-opens-folder []
  (t.reset-workdir)
  (t.mkdir "spec/lib/epoxy")
  (let [state (state [(entry "A" "script/shorthand_branch.sh")
                      (entry "M"
                             "spec/lib/epoxy/version_branch_validation_spec.rb")])
        opened []
        old-open browser.open]
    (set browser.open (fn [path]
                        (table.insert opened path)
                        true))
    (app.handle-key state {} "j")
    (app.handle-key state {} "o")
    (set browser.open old-open)
    (faith.= ["spec/lib/epoxy"] opened)
    (faith.= "Opening: spec/lib/epoxy" state.notice)))

(fn test-open-on-deleted-tree-folder-shows-not-found []
  (t.reset-workdir)
  (let [state (state [(entry "D" "lib/tardis/docker/workers/app.rb")])
        opened []
        old-open browser.open]
    (set state.tree_selected_row 1)
    (set browser.open (fn [path]
                        (table.insert opened path)
                        true))
    (faith.is (app.handle-key state {} "o"))
    (set browser.open old-open)
    (faith.= [] opened)
    (faith.= "Folder not found: lib/tardis/docker/workers" state.notice)))

(fn test-open-on-deleted-file-shows-not-found []
  (t.reset-workdir)
  (let [state (state [(entry "D" "lib/workers/destroy.rb")])
        opened []
        old-run editor.run]
    (set editor.run (fn [_config entry _stty-state]
                      (table.insert opened entry.path)
                      true))
    (faith.is (app.handle-key state {} "o"))
    (set editor.run old-run)
    (faith.= [] opened)
    (faith.= "File not found: lib/workers/destroy.rb" state.notice)))

(fn test-tree-search-matches-folders []
  (let [state (state [(entry "A" "script/shorthand_branch.sh")
                      (entry "M"
                             "spec/lib/epoxy/version_branch_validation_spec.rb")])]
    (app.handle-key state {} "/")
    (app.handle-key state {} "e")
    (app.handle-key state {} "p")
    (app.handle-key state {} "o")
    (app.handle-key state {} "x")
    (faith.= :tree state.view_mode)
    (faith.= 3 state.tree_selected_row)
    (let [view (app.view state 10 100)]
      (faith.is (. view.body.right.lines 1)))))

(fn test-view-folder-preview-for-real-deleted-folders []
  (setup-real-folder-preview-repo)
  (let [state (real-preview-state)]
    (select-folder state "lib/tardis/docker")
    (let [view (app.view state 12 100)
          text (t.text view.body.right.lines)]
      (faith.match "%[M%] api%.rb" text)
      (faith.match "%[D%] views/" text)
      (faith.match "%[D%] workers/" text)
      (faith.not-match "ls:" text))))

(fn test-view-folder-preview-sorts-like-left-tree-for-real-repo []
  (setup-real-folder-preview-repo)
  (let [state (real-preview-state)]
    (select-folder state "lib/tardis/docker")
    (let [view (app.view state 12 100)]
      (faith.= (table.concat ["[M] lib/tardis/docker/"
                              (string.rep "─" 22)
                              "[M] api.rb"
                              "[D] web.rb"
                              "[D] views/"
                              "[D] workers/"] "\n")
               (t.text view.body.right.lines)))))

(fn test-uppercase-e-toggles-nested-folders-and-skips-the-root []
  (t.init-repo)
  (t.mkdir "lib/sub")
  (t.write-file "lib/top.rb" "old\n")
  (t.write-file "lib/sub/nested.rb" "old\n")
  (t.write-file "lib/sub/sibling.rb" "sibling\n")
  (t.commit-all "initial")
  (t.write-file "lib/top.rb" "new\n")
  (t.write-file "lib/sub/nested.rb" "new\n")
  (let [state (real-preview-state)]
    (faith.is (app.handle-key state {} "E"))
    (faith.= nil (. state.expanded_folders "lib"))
    (faith.is (. state.expanded_folders "lib/sub"))
    (let [text (t.text (icollect [_ row (ipairs (selection.rows state))]
                         (or row.name "")))]
      (faith.match "sibling%.rb" text))
    (faith.is (app.handle-key state {} "E"))
    (faith.= nil (. state.expanded_folders "lib/sub"))))

(fn setup-nested-changed-repo []
  (t.init-repo)
  (t.mkdir "lib/sub")
  (t.write-file "lib/top.rb" "old\n")
  (t.write-file "lib/sub/another.rb" "old\n")
  (t.write-file "lib/sub/nested.rb" "old\n")
  (t.write-file "lib/sub/sibling.rb" "sibling\n")
  (t.commit-all "initial")
  (t.write-file "lib/top.rb" "new\n")
  (t.write-file "lib/sub/another.rb" "new\n")
  (t.write-file "lib/sub/nested.rb" "new\n"))

(fn test-e-on-changed-file-expands-parent-and-keeps-cursor []
  (setup-nested-changed-repo)
  (let [state (real-preview-state)]
    (select-file state "nested.rb")
    (faith.is (app.handle-key state {} "e"))
    (faith.is (. state.expanded_folders "lib/sub"))
    (faith.= "nested.rb" (. (selection.selected-tree-row state) :name))
    (let [text (t.text (icollect [_ row (ipairs (selection.rows state))]
                         (or row.name "")))]
      (faith.match "sibling%.rb" text))))

(fn test-e-on-unchanged-file-collapses-and-jumps-to-lowest-file []
  (setup-nested-changed-repo)
  (let [state (real-preview-state)]
    (select-file state "nested.rb")
    (app.handle-key state {} "e")
    (select-file state "sibling.rb")
    (faith.is (app.handle-key state {} "e"))
    (faith.= nil (. state.expanded_folders "lib/sub"))
    (let [row (selection.selected-tree-row state)]
      (faith.= :file row.type)
      (faith.= "nested.rb" row.name))))

(fn setup-sibling-changed-folders []
  (t.init-repo)
  (t.mkdir "lib/a_dir")
  (t.mkdir "lib/b_dir")
  (t.write-file "lib/a_dir/a1.rb" "old\n")
  (t.write-file "lib/a_dir/extra.rb" "extra\n")
  (t.write-file "lib/b_dir/b1.rb" "old\n")
  (t.commit-all "initial")
  (t.write-file "lib/a_dir/a1.rb" "new\n")
  (t.write-file "lib/b_dir/b1.rb" "new\n"))

(fn test-uppercase-e-expand-keeps-cursor-on-changed-file []
  (setup-sibling-changed-folders)
  (let [state (real-preview-state)]
    (select-file state "b1.rb")
    (faith.is (app.handle-key state {} "E"))
    (let [row (selection.selected-tree-row state)]
      (faith.= :file row.type)
      (faith.= "b1.rb" row.name))))

(fn test-uppercase-e-expand-keeps-cursor-on-folder []
  (setup-sibling-changed-folders)
  (let [state (real-preview-state)]
    (select-folder state "lib/b_dir")
    (faith.is (app.handle-key state {} "E"))
    (let [row (selection.selected-tree-row state)]
      (faith.= :folder row.type)
      (faith.= "lib/b_dir" row.path))))

(fn test-uppercase-e-collapse-from-unchanged-file-jumps-to-lowest-file []
  (setup-nested-changed-repo)
  (let [state (real-preview-state)]
    (faith.is (app.handle-key state {} "E"))
    (select-file state "sibling.rb")
    (faith.is (app.handle-key state {} "E"))
    (faith.= nil (. state.expanded_folders "lib/sub"))
    (let [row (selection.selected-tree-row state)]
      (faith.= :file row.type)
      (faith.= "nested.rb" row.name))))

(fn test-view-moves-file-counts-to-header-right []
  (let [state (state [(entry "M" "a.rb") (entry "A" "b.rb")])]
    (let [first-entry (. state.entries 1)]
      (set first-entry.reviewed true))
    (let [view (app.view state 10 100)
          header-left (tui.strip-ansi view.header.text)
          header-right (tui.strip-ansi view.header.right)]
      (faith.= nil (header-left:find "files" 1 true))
      (faith.= nil (header-left:find "reviewed" 1 true))
      (faith.= "1/2 files │ 50% reviewed" header-right))))

(fn test-view-shows-diff-stats-in-header-right []
  (let [state (state [(entry "M" "a.rb") (entry "A" "b.rb")])]
    (set state.diff_stats {:additions 42 :deletions 7})
    (let [view (app.view state 10 100)
          header-right (tui.strip-ansi view.header.right)]
      (faith.= "0/2 files │ 0% reviewed │ +42 -7" header-right))))

(fn test-view-shows-reviewed-file-percent-in-header-right []
  (let [state (state [(entry "M" "a.rb") (entry "A" "b.rb")])]
    (let [first-entry (. state.entries 1)]
      (set first-entry.reviewed true))
    (set state.diff_stats
         {:additions 10
          :deletions 5
          :files {"a.rb" {:additions 3 :deletions 2}
                  "b.rb" {:additions 7 :deletions 3}}})
    (let [view (app.view state 10 100)
          header-right (tui.strip-ansi view.header.right)]
      (faith.= "1/2 files │ 50% reviewed │ +10 -5" header-right))))

(fn test-view-shows-all-reviewed-when-all-files-reviewed []
  (let [state (state [(entry "M" "a.rb") (entry "M" "renamed.rb")])]
    (each [_ entry (ipairs state.entries)]
      (set entry.reviewed true))
    (set state.diff_stats
         {:additions 100
          :deletions 20
          :files {"a.rb" {:additions 10 :deletions 5}}})
    (let [view (app.view state 10 100)
          header-right (tui.strip-ansi view.header.right)]
      (faith.= "2/2 files │ 100% reviewed │ +100 -20" header-right))))

(fn test-view-shows-trimmed-header []
  (let [state (state [(entry "M" "a.rb")])
        view (app.view state 10 100)
        header (tui.strip-ansi view.header.text)]
    (faith.is (header:find "? help" 1 true))
    (faith.is (header:find "Ctrl-C quit" 1 true))
    (faith.= nil (header:find "refresh/sync" 1 true))
    (faith.= nil (header:find "w wrap" 1 true))))

(fn test-view-shows-toggle-status-in-footer-right []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.view_mode :tree)
    (set state.preview_wrap? true)
    (set state.show_numbers? false)
    (set state.show_blame? false)
    (set state.split_mode? true)
    (set state.full_context? false)
    (set state.hide_reviewed? false)
    (let [view (app.view state 10 100)
          footer-right (tui.strip-ansi view.footer.right)]
      (faith.= "tree on │ wrap on │ num off │ blame off │ split on │ context off │ hide off"
               footer-right))))

(fn test-view-reflects-toggled-status-in-footer-right []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.view_mode :flat)
    (set state.preview_wrap? false)
    (set state.show_numbers? true)
    (set state.show_blame? true)
    (set state.split_mode? false)
    (set state.full_context? true)
    (set state.hide_reviewed? true)
    (let [view (app.view state 10 100)
          footer-right (tui.strip-ansi view.footer.right)]
      (faith.= "tree off │ wrap off │ num on │ blame on │ split off │ context on │ hide on"
               footer-right))))

(fn test-uppercase-h-hides-reviewed-entries-from-list []
  (let [state (state [(entry "M" "a.rb") (entry "M" "b.rb") (entry "M" "c.rb")])]
    (let [second (. state.entries 2)]
      (set second.reviewed true))
    (faith.= 3 (length (selection.rows state)))
    (faith.is (app.handle-key state {} "H"))
    (faith.= true state.hide_reviewed?)
    (faith.= 2 (length (selection.rows state)))
    (faith.is (app.handle-key state {} "H"))
    (faith.= false state.hide_reviewed?)
    (faith.= 3 (length (selection.rows state)))))

(fn test-hide-reviewed-skips-hidden-entries-in-flat-navigation []
  (let [state (flat-state [(entry "M" "a.rb")
                           (entry "M" "b.rb")
                           (entry "M" "c.rb")])]
    (let [second (. state.entries 2)]
      (set second.reviewed true))
    (app.handle-key state {} "H")
    (faith.= 1 state.selected)
    (app.handle-key state {} "j")
    (faith.= 3 state.selected)
    (app.handle-key state {} "j")
    (faith.= 3 state.selected)))

(fn test-hide-reviewed-keeps-cursor-on-unreviewed-selection []
  (let [state (state [(entry "M" "a.rb") (entry "M" "b.rb") (entry "M" "c.rb")])]
    (app.handle-key state {} "j")
    (faith.= 2 state.tree_selected_row)
    (let [first-entry (. state.entries 1)]
      (set first-entry.reviewed true))
    (app.handle-key state {} "H")
    (let [row (selection.selected-tree-row state)]
      (faith.= :file row.type)
      (faith.= "b.rb" row.name))))

(fn test-question-mark-toggles-help-modal []
  (let [state (state [(entry "M" "a.rb")])]
    (faith.= nil (. (app.view state 10 100) :overlay))
    (faith.is (app.handle-key state {} "?"))
    (faith.is state.show_help?)
    (faith.= :modal (. (app.view state 10 100) :overlay :type))
    (faith.is (app.handle-key state {} "q"))
    (faith.is (not state.show_help?))
    (faith.= nil (. (app.view state 10 100) :overlay))))

(fn test-help-modal-ignores-action-keys-without-redraw []
  (let [state (state [(entry "M" "a.rb")])]
    (app.handle-key state {} "?")
    (faith.is state.show_help?)
    (each [_ key (ipairs [:enter "p" "j" "o"])]
      (faith.is (app.handle-key state {} key))
      (faith.is state.show_help?)
      (faith.is state.skip_next_draw?))))

(fn test-help-modal-skips-redraw-on-idle-tick []
  (let [state (state [(entry "M" "a.rb")])]
    (app.handle-key state {} "?")
    (faith.is state.show_help?)
    (app.handle-key state {} :tick)
    (faith.is state.show_help?)
    (faith.is state.skip_next_draw?)))

(fn test-escape-closes-help-modal []
  (let [state (state [(entry "M" "a.rb")])]
    (app.handle-key state {} "?")
    (faith.is state.show_help?)
    (faith.is (app.handle-key state {} :escape))
    (faith.is (not state.show_help?))))

(fn test-view-clamps-preview-horizontal-scroll-when-content-fits []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.preview_x_scroll 16)
    (let [view (app.view state 10 100)]
      (faith.= 0 view.body.right.x-scroll))))

(fn test-view-passes-preview-horizontal-scroll-when-content-overflows []
  (let [selected (entry "M" "a.rb")
        state (state [selected])
        key (preview-key.for-entry "HEAD" selected)]
    (tset state.preview_cache key ["abcdefghijklmnopqrstuvwxyz"])
    (set state.preview_wrap? false)
    (set state.preview_x_scroll 16)
    (let [view (app.view state 10 30)]
      (faith.= 8 view.body.right.x-scroll)
      (faith.= 8 view.body.right.x-max-scroll)
      (faith.= 8 state.preview_x_max_scroll))))

(fn test-view-uses-whole-preview-for-horizontal-scroll-limit []
  (let [selected (entry "M" "a.rb")
        state (state [selected])
        key (preview-key.for-entry "HEAD" selected)]
    (tset state.preview_cache key ["short" "tiny" "abcdefghijklmnopqrstuvwxyz"])
    (set state.preview_wrap? false)
    (set state.preview_x_scroll 100)
    (let [view (app.view state 6 30)]
      (faith.= "short\ntiny" (t.text view.body.right.lines))
      (faith.= 9 view.body.right.x-scroll)
      (faith.= 9 view.body.right.x-max-scroll)
      (faith.= 9 state.preview_x_max_scroll))))

(fn test-view-wraps-preview-lines-when-enabled []
  (let [selected (entry "M" "a.rb")
        state (state [selected])
        key (preview-key.for-entry "HEAD" selected)]
    (tset state.preview_cache key ["abcdefghijklmnopqrstuvwxyz"])
    (set state.preview_wrap? true)
    (set state.preview_x_scroll 10)
    (let [view (app.view state 6 20)]
      (faith.= "abcdefghij↪\nklmnopqrst↪" (t.text view.body.right.lines))
      (faith.= 0 view.body.right.x-scroll)
      (faith.= 0 view.body.right.x-max-scroll)
      (faith.= 3 state.preview_total)
      (faith.= 0 state.preview_x_scroll))))

(fn test-view-highlights-preview-cursor-only-when-diff-focused []
  (let [selected (entry "M" "a.rb")
        state (state [selected])
        key (preview-key.for-entry "HEAD" selected)]
    (tset state.preview_cache key ["one" "two" "three" "four" "five"])
    (faith.= nil (. (app.view state 10 80) :body :right :highlight))
    (set state.focus :right)
    (set state.preview_cursor 3)
    (let [view (app.view state 10 80)
          highlighted (tui.strip-ansi (. view.body.right.lines 3))]
      (faith.= 3 view.body.right.highlight)
      (faith.= "three" (t.text [highlighted]))
      (faith.is (not (string.find (. view.body.right.lines 3) ">"))))))

(fn test-toggling-full-context-rebuilds-the-preview-search []
  (let [selected (entry "M" "a.rb")
        state (state [selected])
        normal (preview-key.for-entry "HEAD" selected false)
        full (preview-key.for-entry "HEAD" selected true)]
    (tset state.preview_cache normal ["alpha" "beta apple" "gamma"])
    (tset state.preview_cache full ["apple one" "two" "three" "four apple"])
    (set state.focus :right)
    (update.update state {} (update.read-msg state "/"))
    (each [_ ch (ipairs ["a" "p" "p" "l" "e"])]
      (update.update state {} (update.read-msg state ch)))
    (update.update state {} (update.read-msg state :enter))
    (app.view state 10 80)
    (faith.= 1 (length state.preview_search.matches))
    (faith.= 2 (. state.preview_search.matches 1 :line))
    (update.update state {} (update.read-msg state "c"))
    (app.view state 10 80)
    (faith.= 2 (length state.preview_search.matches))
    (faith.= 1 (. state.preview_search.matches 1 :line))
    (faith.= 4 (. state.preview_search.matches 2 :line))))

(fn test-view-clamps-file-horizontal-scroll-when-file-rows-fit []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.files_x_scroll 8)
    (let [view (app.view state 10 80)]
      (faith.= 0 view.body.left.x-scroll)
      (faith.= 0 state.files_x_max_scroll))))

(fn test-view-keeps-file-list-horizontal-scroll-disabled []
  (let [state (state [(entry "M"
                             "really/long/path/that/does/not/fit/in/the/list.rb")])]
    (set state.files_x_scroll 100)
    (let [view (app.view state 10 30)]
      (faith.= 0 view.body.left.x-scroll)
      (faith.= 0 view.body.left.x-max-scroll)
      (faith.= 0 state.files_x_scroll)
      (faith.= 0 state.files_x_max_scroll))))

(fn test-view-adds-left-scroll-info-for-overflowing-file-list []
  (let [state (state [(entry "M" "1.rb")
                      (entry "M" "2.rb")
                      (entry "M" "3.rb")
                      (entry "M" "4.rb")
                      (entry "M" "5.rb")])
        view (app.view state 6 100)]
    (faith.= {:offset 0 :total 5 :visible 2} view.body.left.scroll)))

(fn test-view-keeps-last-file-above-bottom-divider []
  (let [state (flat-state [(entry "M" "1.rb")
                           (entry "M" "2.rb")
                           (entry "M" "3.rb")
                           (entry "M" "4.rb")
                           (entry "M" "5.rb")])]
    (set state.selected 5)
    (let [view (app.view state 6 100)
          rows view.body.left.rows]
      (faith.= 2 (length rows))
      (faith.= "> [ ] [M] 5.rb" (plain-row-text (. rows 2))))))

(fn test-split-key-does-not-start-due-sync []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.sync.next_at 0)
    (faith.is (app.handle-key state {} "]"))
    (faith.= false state.sync.running?)
    (faith.almost= 0.45 state.split_ratio 0.0001)))

(fn test-quit-cleans-preview-warmer []
  (t.reset-workdir)
  (t.mkdir "warm")
  (t.write-file "warm/manifest.fnl" "{}")
  (let [state (state [(entry "M" "a.rb")])]
    (set state.preview_warm.dir "warm")
    (faith.= false (app.handle-key state {} :quit))
    (faith.= true state.quit?)
    (faith.= nil state.preview_warm.dir)
    (faith.= false (sys.write-file "warm/still-there" "x"))))

(fn test-manual-clean-remote-sync-finish-updates-notice []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.sync.running? true)
    (set state.show_sync_notice? true)
    (faith.is (sys.write-file state.sync.path
                              "branch\tfeature\torigin/feature\t0\t0\n"))
    (faith.is (app.handle-key state {} :tick))
    (faith.= nil state.sync.warning)
    (faith.= "Remote in sync" state.notice)))

(fn test-remote-sync-finish-is-polled-on-input []
  (let [state (state [(entry "M" "a.rb") (entry "M" "b.rb")])]
    (set state.sync.running? true)
    (set state.show_sync_notice? true)
    (faith.is (sys.write-file state.sync.path
                              "branch\tfeature\torigin/feature\t0\t0\n"))
    (faith.is (app.handle-key state {} "j"))
    (faith.= 2 state.selected)
    (faith.= false state.sync.running?)
    (faith.= "Remote in sync" state.notice)))

(fn test-fetch-failure-shows-sync-notice-not-success []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.sync.running? true)
    (set state.show_sync_notice? true)
    (faith.is (sys.write-file state.sync.path "fetch-error\t128\n"))
    (faith.is (app.handle-key state {} :tick))
    (faith.= nil state.sync.warning)
    (faith.= "Could not sync remote" state.notice)))

(fn test-no-upstream-shows-sync-notice-not-warning []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.sync.running? true)
    (set state.show_sync_notice? true)
    (faith.is (sys.write-file state.sync.path "no-upstream\ttest2\n"))
    (faith.is (app.handle-key state {} :tick))
    (faith.= nil state.sync.warning)
    (faith.= "No upstream for test2" state.notice)))

(fn test-startup-clean-remote-sync-finish-stays-quiet []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.sync.running? true)
    (faith.is (sys.write-file state.sync.path
                              "branch\tfeature\torigin/feature\t0\t0\n"))
    (faith.is (app.handle-key state {} :tick))
    (faith.= nil state.sync.warning)
    (faith.= nil state.notice)))

(fn test-startup-fetch-failure-shows-sync-notice []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.sync.running? true)
    (faith.is (sys.write-file state.sync.path "fetch-error\t128\n"))
    (faith.is (app.handle-key state {} :tick))
    (faith.= nil state.sync.warning)
    (faith.= "Could not sync remote" state.notice)))

(fn test-remote-sync-warning-persists-until-clean-sync []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.sync.running? true)
    (set state.show_sync_notice? true)
    (faith.is (sys.write-file state.sync.path
                              "branch\tfeature\torigin/feature\t0\t2\n"))
    (faith.is (app.handle-key state {} :tick))
    (faith.= "Branch not in sync: feature vs origin/feature (+0/-2)"
             state.sync.warning)
    (set state.sync.running? true)
    (set state.show_sync_notice? true)
    (faith.is (sys.write-file state.sync.path
                              "branch\tfeature\torigin/feature\t0\t0\n"))
    (faith.is (app.handle-key state {} :tick))
    (faith.= nil state.sync.warning)
    (faith.= "Remote in sync" state.notice)))

(fn test-view-imports-only-selected-ready-preview-during-cursor-redraw []
  (t.reset-workdir)
  (t.mkdir "warm")
  (let [selected (entry "M" "a.rb")
        warmed (entry "M" "b.rb")
        state (state [selected warmed])
        selected-key (preview-key.for-entry "HEAD" selected)
        warmed-key (preview-key.for-entry "HEAD" warmed)]
    (faith.is (sys.write-file "warm/1.fnl" (fennel.view {:lines ["selected"]})))
    (faith.is (sys.write-file "warm/2.fnl" (fennel.view {:lines ["warmed"]})))
    (set state.preview_warm
         {:dir "warm"
          :count 2
          :remaining 2
          :scan-index 1
          :imported {}
          :key-index {selected-key 1 warmed-key 2}
          :index-key {1 selected-key 2 warmed-key}})
    (let [view (app.view state 10 100)]
      (faith.= "selected" (t.text view.body.right.lines)))
    (faith.= ["selected"] (. state.preview_cache selected-key))
    (faith.= nil (. state.preview_cache warmed-key))
    (app.handle-key state {} :tick)
    (faith.= ["warmed"] (. state.preview_cache warmed-key))))

{: test-lowercase-a-toggles-all-reviewed-and-uppercase-a-does-nothing
 : test-search-next-is-relative-to-current-cursor
 : test-backtick-preserves-selected-file-with-search
 : test-backtick-toggles-tree-mode-without-clearing-search
 : test-fetch-failure-shows-sync-notice-not-success
 : test-manual-clean-remote-sync-finish-updates-notice
 : test-no-upstream-shows-sync-notice-not-warning
 : test-remote-sync-finish-is-polled-on-input
 : test-remote-sync-warning-persists-until-clean-sync
 : test-quit-cleans-preview-warmer
 : test-startup-clean-remote-sync-finish-stays-quiet
 : test-startup-fetch-failure-shows-sync-notice
 : test-split-key-does-not-start-due-sync
 : test-open-on-deleted-file-shows-not-found
 : test-open-on-deleted-tree-folder-shows-not-found
 : test-open-on-tree-folder-opens-folder
 : test-space-on-tree-folder-toggles-descendant-files
 : test-view-styles-reviewed-checkbox-brackets-as-muted
 : test-tree-mode-navigation-moves-between-folders-and-files
 : test-tree-search-matches-folders
 : test-tree-view-renders-collapsed-folders-and-file-rows
 : test-view-adds-left-scroll-info-for-overflowing-file-list
 : test-view-keeps-last-file-above-bottom-divider
 : test-uppercase-e-toggles-nested-folders-and-skips-the-root
 : test-e-on-changed-file-expands-parent-and-keeps-cursor
 : test-e-on-unchanged-file-collapses-and-jumps-to-lowest-file
 : test-uppercase-e-expand-keeps-cursor-on-changed-file
 : test-uppercase-e-expand-keeps-cursor-on-folder
 : test-uppercase-e-collapse-from-unchanged-file-jumps-to-lowest-file
 : test-view-moves-file-counts-to-header-right
 : test-view-shows-all-reviewed-when-all-files-reviewed
 : test-view-shows-reviewed-file-percent-in-header-right
 : test-view-shows-diff-stats-in-header-right
 : test-view-shows-trimmed-header
 : test-view-shows-toggle-status-in-footer-right
 : test-view-reflects-toggled-status-in-footer-right
 : test-uppercase-h-hides-reviewed-entries-from-list
 : test-hide-reviewed-skips-hidden-entries-in-flat-navigation
 : test-hide-reviewed-keeps-cursor-on-unreviewed-selection
 : test-question-mark-toggles-help-modal
 : test-help-modal-ignores-action-keys-without-redraw
 : test-help-modal-skips-redraw-on-idle-tick
 : test-escape-closes-help-modal
 : test-view-clamps-preview-horizontal-scroll-when-content-fits
 : test-view-highlights-preview-cursor-only-when-diff-focused
 : test-toggling-full-context-rebuilds-the-preview-search
 : test-view-clamps-file-horizontal-scroll-when-file-rows-fit
 : test-view-keeps-file-list-horizontal-scroll-disabled
 : test-view-folder-preview-for-real-deleted-folders
 : test-view-folder-preview-sorts-like-left-tree-for-real-repo
 : test-view-passes-preview-horizontal-scroll-when-content-overflows
 : test-view-uses-whole-preview-for-horizontal-scroll-limit
 : test-view-wraps-preview-lines-when-enabled
 : test-view-imports-only-selected-ready-preview-during-cursor-redraw
 : test-view-renders-renames-with-short-status}
