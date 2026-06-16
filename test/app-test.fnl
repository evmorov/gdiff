(local app (require :app.core))
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
  (let [state (state [(entry "M" "api/v1.rb")
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
  (let [state (state [(entry "R" "spec/tardis/api/v2_spec.rb"
                             "spec/tardis/api_spec.rb")])
        view (app.view state 10 100)]
    (faith.= "> [ ] [R] spec/tardis/api/v2_spec.rb <- spec/tardis/api_spec.rb"
             (plain-row-text (. view.body.left.rows 1)))))

(fn test-view-moves_file_counts_to_footer_right []
  (let [state (state [(entry "M" "a.rb") (entry "A" "b.rb")])]
    (let [first-entry (. state.entries 1)]
      (set first-entry.reviewed true))
    (let [view (app.view state 10 100)
          header (tui.strip-ansi view.header)
          footer-right (tui.strip-ansi view.footer.right)]
      (faith.= nil (header:find "files" 1 true))
      (faith.= nil (header:find "reviewed" 1 true))
      (faith.= "1/2 reviewed │ 2 files" footer-right))))

(fn test-view-shows-single-refresh-sync-key []
  (let [state (state [(entry "M" "a.rb")])
        view (app.view state 10 100)
        header (tui.strip-ansi view.header)]
    (faith.match "r refresh/sync" header)
    (faith.= nil (header:find "R sync" 1 true))))

(fn test-view-adds-left-scroll-info-for-overflowing-file-list []
  (let [state (state [(entry "M" "1.rb")
                      (entry "M" "2.rb")
                      (entry "M" "3.rb")
                      (entry "M" "4.rb")
                      (entry "M" "5.rb")])
        view (app.view state 6 100)]
    (faith.= {:offset 0 :total 5 :visible 2} view.body.left.scroll)))

(fn test-view-keeps_last_file_above_bottom_divider []
  (let [state (state [(entry "M" "1.rb")
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
    (faith.is (app.handle-key state {} ">"))
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
 : test-fetch-failure-shows-sync-notice-not-success
 : test-manual-clean-remote-sync-finish-updates-notice
 : test-remote-sync-finish-is-polled-on-input
 : test-remote-sync-warning-persists-until-clean-sync
 : test-quit-cleans-preview-warmer
 : test-startup-clean-remote-sync-finish-stays-quiet
 : test-startup-fetch-failure-shows-sync-notice
 : test-split-key-does-not-start-due-sync
 : test-view-adds-left-scroll-info-for-overflowing-file-list
 : test-view-keeps_last_file_above_bottom_divider
 : test-view-moves_file_counts_to_footer_right
 : test-view-shows-single-refresh-sync-key
 : test-view-imports-only-selected-ready-preview-during-cursor-redraw
 : test-view-renders-renames-with-short-status}
