(local app (require :app.core))
(local browser (require :platform.browser))
(local faith (require :faith))
(local fennel (require :fennel))
(local preview-key (require :preview.key))
(local reviews (require :storage.reviews))
(local sys (require :platform.core))
(local t (require :test-helper))
(local tui (require :tui.core))

(fn entry [status path ?old-path]
  {:status status
   :kind (status:sub 1 1)
   :path path
   :old_path ?old-path
   :reviewed false})

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

(fn test-a-toggles-all-reviewed-and-A-does-nothing []
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

(fn test-view-styles_reviewed_checkbox_brackets_as_muted []
  (let [state (flat-state [(entry "M" "a.rb")])
        first-entry (. state.entries 1)]
    (set first-entry.reviewed true)
    (let [view (app.view state 10 100)
          text (. (. view.body.left.rows 1) :text)]
      (faith.= "> [x] [M] a.rb" (tui.strip-ansi text))
      (when (text:find "\27" 1 true)
        (faith.is (text:find "\27[2m%[" 1))
        (faith.is (text:find "\27[2m%]" 1))))))

(fn test-backtick_toggles_tree_mode_without_clearing_search []
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

(fn test-backtick_preserves_selected_file_with_search []
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

(fn test-tree_view_renders_collapsed_folders_and_file_rows []
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

(fn test-tree_mode_navigation_moves_between_folders_and_files []
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

(fn test-space_on_tree_folder_toggles_descendant_files []
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

(fn test-open_on_tree_folder_opens_folder []
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

(fn test-tree_search_matches_folders []
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

(fn test-view-moves_file_counts_to_footer_right []
  (let [state (state [(entry "M" "a.rb") (entry "A" "b.rb")])]
    (let [first-entry (. state.entries 1)]
      (set first-entry.reviewed true))
    (let [view (app.view state 10 100)
          header (tui.strip-ansi view.header)
          footer-right (tui.strip-ansi view.footer.right)]
      (faith.= nil (header:find "files" 1 true))
      (faith.= nil (header:find "reviewed" 1 true))
      (faith.= "1/2 files │ 50% reviewed" footer-right))))

(fn test-view-shows_diff_stats_in_footer_right []
  (let [state (state [(entry "M" "a.rb") (entry "A" "b.rb")])]
    (set state.diff_stats {:additions 42 :deletions 7})
    (let [view (app.view state 10 100)
          footer-right (tui.strip-ansi view.footer.right)]
      (faith.= "0/2 files │ 0% reviewed │ +42 -7" footer-right))))

(fn test-view-shows_reviewed_file_percent_in_footer_right []
  (let [state (state [(entry "M" "a.rb") (entry "A" "b.rb")])]
    (let [first-entry (. state.entries 1)]
      (set first-entry.reviewed true))
    (set state.diff_stats
         {:additions 10
          :deletions 5
          :files {"a.rb" {:additions 3 :deletions 2}
                  "b.rb" {:additions 7 :deletions 3}}})
    (let [view (app.view state 10 100)
          footer-right (tui.strip-ansi view.footer.right)]
      (faith.= "1/2 files │ 50% reviewed │ +10 -5" footer-right))))

(fn test-view-shows_all_reviewed_when_all_files_reviewed []
  (let [state (state [(entry "M" "a.rb") (entry "M" "renamed.rb")])]
    (each [_ entry (ipairs state.entries)]
      (set entry.reviewed true))
    (set state.diff_stats
         {:additions 100
          :deletions 20
          :files {"a.rb" {:additions 10 :deletions 5}}})
    (let [view (app.view state 10 100)
          footer-right (tui.strip-ansi view.footer.right)]
      (faith.= "2/2 files │ 100% reviewed │ +100 -20" footer-right))))

(fn test-view-shows-single-refresh-sync-key []
  (let [state (state [(entry "M" "a.rb")])
        view (app.view state 10 100)
        header (tui.strip-ansi view.header)]
    (faith.match "r refresh/sync" header)
    (faith.match "w wrap" header)
    (faith.= nil (header:find "h/l preview" 1 true))
    (faith.= nil (header:find "R sync" 1 true))))

(fn test-view-clamps_preview_horizontal_scroll_when_content_fits []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.preview_x_scroll 16)
    (let [view (app.view state 10 100)]
      (faith.= 0 view.body.right.x-scroll))))

(fn test-view-passes_preview_horizontal_scroll_when_content_overflows []
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

(fn test-view-uses_whole_preview_for_horizontal_scroll_limit []
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

(fn test-view-wraps_preview_lines_when_enabled []
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

(fn test-view-clamps_file_horizontal_scroll_when_file_rows_fit []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.files_x_scroll 8)
    (let [view (app.view state 10 80)]
      (faith.= 0 view.body.left.x-scroll)
      (faith.= 0 state.files_x_max_scroll))))

(fn test-view-keeps_file_list_horizontal_scroll_disabled []
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

(fn test-view-keeps_last_file_above_bottom_divider []
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
    (faith.is (sys.write-file "warm/1.fnl" (fennel.view ["selected"])))
    (faith.is (sys.write-file "warm/2.fnl" (fennel.view ["warmed"])))
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

{: test-a-toggles-all-reviewed-and-A-does-nothing
 : test-search-next-is-relative-to-current-cursor
 : test-backtick_preserves_selected_file_with_search
 : test-backtick_toggles_tree_mode_without_clearing_search
 : test-fetch-failure-shows-sync-notice-not-success
 : test-manual-clean-remote-sync-finish-updates-notice
 : test-no-upstream-shows-sync-notice-not-warning
 : test-remote-sync-finish-is-polled-on-input
 : test-remote-sync-warning-persists-until-clean-sync
 : test-quit-cleans-preview-warmer
 : test-startup-clean-remote-sync-finish-stays-quiet
 : test-startup-fetch-failure-shows-sync-notice
 : test-split-key-does-not-start-due-sync
 : test-open_on_tree_folder_opens_folder
 : test-space_on_tree_folder_toggles_descendant_files
 : test-view-styles_reviewed_checkbox_brackets_as_muted
 : test-tree_mode_navigation_moves_between_folders_and_files
 : test-tree_search_matches_folders
 : test-tree_view_renders_collapsed_folders_and_file_rows
 : test-view-adds-left-scroll-info-for-overflowing-file-list
 : test-view-keeps_last_file_above_bottom_divider
 : test-view-moves_file_counts_to_footer_right
 : test-view-shows_all_reviewed_when_all_files_reviewed
 : test-view-shows_reviewed_file_percent_in_footer_right
 : test-view-shows_diff_stats_in_footer_right
 : test-view-shows-single-refresh-sync-key
 : test-view-clamps_preview_horizontal_scroll_when_content_fits
 : test-view-clamps_file_horizontal_scroll_when_file_rows_fit
 : test-view-keeps_file_list_horizontal_scroll_disabled
 : test-view-passes_preview_horizontal_scroll_when_content_overflows
 : test-view-uses_whole_preview_for_horizontal_scroll_limit
 : test-view-wraps_preview_lines_when_enabled
 : test-view-imports-only-selected-ready-preview-during-cursor-redraw
 : test-view-renders-renames-with-short-status}
