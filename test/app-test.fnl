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

(fn test-view-adds-left-scroll-info-for-overflowing-file-list []
  (let [state (state [(entry "M" "1.rb")
                      (entry "M" "2.rb")
                      (entry "M" "3.rb")
                      (entry "M" "4.rb")
                      (entry "M" "5.rb")])
        view (app.view state 6 100)]
    (faith.= {:offset 0 :total 5 :visible 3} view.body.left.scroll)))

(fn test-split-key-does-not-start-due-sync []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.sync.next_at 0)
    (faith.is (app.handle-key state {} ">"))
    (faith.= false state.sync.running?)
    (faith.almost= 0.45 state.split_ratio 0.0001)))

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
 : test-split-key-does-not-start-due-sync
 : test-view-adds-left-scroll-info-for-overflowing-file-list
 : test-view-imports-only-selected-ready-preview-during-cursor-redraw
 : test-view-renders-renames-with-short-status}
