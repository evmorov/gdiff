(local faith (require :faith))
(local clipboard (require :platform.clipboard))
(local preview-key (require :preview.key))
(local reviews (require :storage.reviews))
(local update (require :app.update))

(fn entry [status path]
  {: status :kind (status:sub 1 1) : path :reviewed false})

(fn state [entries]
  (let [state (update.init "HEAD" entries {:version 1 :reviews {}} "scope"
                           "src")]
    (set state.sync.next_at (+ (os.time) 999))
    state))

(fn test-read-msg-turns-raw-key-into-message-data []
  (let [state (state [(entry "M" "a.rb")])]
    (faith.= {:type :toggle-all-reviewed} (update.read-msg state "a"))
    (faith.= {:type :toggle-wrap} (update.read-msg state "w"))
    (faith.= {:type :toggle-blame} (update.read-msg state "b"))
    (faith.= {:type :open-pr} (update.read-msg state "p"))))

(fn test-read-msg-keeps-pending-g-in-state []
  (let [state (state [(entry "M" "a.rb")])]
    (faith.= {:type :pending-key :pending-key "g"} (update.read-msg state "g"))
    (faith.= nil state.pending-key)
    (update.update state {} (update.read-msg state "g"))
    (faith.= "g" state.pending-key)
    (faith.= {:type :top} (update.read-msg state "g"))
    (update.update state {} (update.read-msg state "g"))
    (faith.= nil state.pending-key)))

(fn test-unknown-key-clears-pending-g []
  (let [state (state [(entry "M" "a.rb")])]
    (update.update state {} (update.read-msg state "g"))
    (faith.= "g" state.pending-key)
    (update.update state {} (update.read-msg state "x"))
    (faith.= nil state.pending-key)
    (faith.= {:type :pending-key :pending-key "g"} (update.read-msg state "g"))))

(fn test-update-returns-command-for-review-persistence []
  (let [state (state [(entry "M" "a.rb")])
        (_ command) (update.update state {} {:type :toggle-all-reviewed})]
    (faith.= {"a.rb" true} (reviews.paths state.entries))
    (faith.= "Marked all reviewed" state.notice)
    (faith.= :function (type command))))

(fn test-local-refresh-does-not-start-remote-sync []
  (let [state (state [])
        (_ command) (update.update state {}
                                   {:type :refresh-loaded
                                    :entries []
                                    :reviewed {}})]
    (update.run-command state {} command)
    (faith.= false state.sync.running?)))

(fn test-lowercase-r-refreshes-files-and-starts-sync []
  (let [state (state [(entry "M" "a.rb")])
        (_ command) (update.update state {} (update.read-msg state "r"))]
    (faith.= :function (type command))
    (faith.= "Syncing remote..." state.notice)
    (faith.= true state.show_sync_notice?)))

(fn refresh-loaded-msg [entries]
  {:type :refresh-loaded : entries :reviewed {}})

(fn seed-preview-cache [state]
  (set state.preview_cache
       {(preview-key.for-entry "HEAD" (entry "M" "a.rb")) (fcollect [i 1 10]
                                                            (.. "line " i))})
  (set state.preview_total 10)
  (set state.preview_rows 5))

(fn test-refresh-keeps-preview-cursor-when-diff-focused []
  (let [state (state [(entry "M" "a.rb")])]
    (seed-preview-cache state)
    (update.update state {} (update.read-msg state "\t"))
    (for [_ 1 4]
      (update.update state {} (update.read-msg state "j")))
    (faith.= 5 state.preview_cursor)
    (update.update state {} (refresh-loaded-msg [(entry "M" "a.rb")]))
    (faith.= 5 state.preview_cursor)))

(fn test-refresh-resets-preview-cursor-when-files-focused []
  (let [state (state [(entry "M" "a.rb")])]
    (seed-preview-cache state)
    (set state.preview_cursor 5)
    (faith.= :left state.focus)
    (update.update state {} (refresh-loaded-msg [(entry "M" "a.rb")]))
    (faith.= 1 state.preview_cursor)))

(fn test-refresh-keeps-preview-scroll-when-files-focused []
  (let [state (state [(entry "M" "a.rb")])]
    (seed-preview-cache state)
    (set state.preview_scroll 3)
    (faith.= :left state.focus)
    (update.update state {} (refresh-loaded-msg [(entry "M" "a.rb")]))
    (faith.= 3 state.preview_scroll)
    (faith.= 4 state.preview_cursor)))

(fn test-refresh-clears-stale-preview-cache []
  (let [state (state [(entry "M" "a.rb")])
        stale-key (preview-key.for-entry "HEAD" (entry "M" "gone.rb"))]
    (seed-preview-cache state)
    (tset state.preview_cache stale-key ["stale"])
    (update.update state {} (refresh-loaded-msg [(entry "M" "a.rb")]))
    (faith.= nil (. state.preview_cache stale-key))))

(fn test-uppercase-r-does-not-start-sync []
  (let [state (state [(entry "M" "a.rb")])
        (_ command) (update.update state {} (update.read-msg state "R"))]
    (update.run-command state {} command)
    (faith.= nil state.notice)
    (faith.= false state.show_sync_notice?)
    (faith.= false state.sync.running?)))

(fn test-uppercase-r-does-not-attach-to-startup-sync []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.sync.running? true)
    (let [(_ command) (update.update state {} (update.read-msg state "R"))]
      (update.run-command state {} command)
      (faith.= nil state.notice)
      (faith.= false state.show_sync_notice?)
      (faith.= true state.sync.running?))))

(fn test-start-command-starts-remote-sync-quietly []
  (let [state (state [(entry "M" "a.rb")])
        command (update.start-command state)]
    (faith.= :function (type command))
    (faith.= nil state.notice)))

(fn test-split-keys-move-divider-by-five-percent []
  (let [state (state [(entry "M" "a.rb")])]
    (update.update state {} (update.read-msg state "["))
    (faith.almost= 0.35 state.split_ratio 0.0001)
    (update.update state {} (update.read-msg state "]"))
    (faith.almost= 0.4 state.split_ratio 0.0001)))

(fn test-split-ratio-is-clamped []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.split_ratio 0.1)
    (update.update state {} (update.read-msg state "["))
    (faith.= 0.1 state.split_ratio)
    (set state.split_ratio 0.9)
    (update.update state {} (update.read-msg state "]"))
    (faith.= 0.9 state.split_ratio)))

(fn test-h-l-scroll-preview-horizontally []
  (let [state (state [(entry "M" "a.rb")])]
    (let [(_ command) (update.update state {} (update.read-msg state "l"))]
      (faith.= :function (type command)))
    (faith.= 0 state.preview_x_scroll)
    (faith.= true state.skip_next_draw?)
    (faith.= 0 state.files_x_scroll)
    (set state.preview_x_max_scroll 12)
    (set state.files_x_max_scroll 20)
    (update.update state {} (update.read-msg state "l"))
    (faith.= 8 state.preview_x_scroll)
    (faith.= false state.skip_next_draw?)
    (faith.= 0 state.files_x_scroll)
    (update.update state {} (update.read-msg state "l"))
    (faith.= 12 state.preview_x_scroll)
    (faith.= false state.skip_next_draw?)
    (faith.= 0 state.files_x_scroll)
    (update.update state {} (update.read-msg state "l"))
    (faith.= 12 state.preview_x_scroll)
    (faith.= true state.skip_next_draw?)
    (update.update state {} (update.read-msg state "h"))
    (faith.= 4 state.preview_x_scroll)
    (faith.= false state.skip_next_draw?)
    (faith.= 0 state.files_x_scroll)
    (update.update state {} (update.read-msg state "h"))
    (faith.= 0 state.preview_x_scroll)
    (faith.= false state.skip_next_draw?)
    (update.update state {} (update.read-msg state "h"))
    (faith.= 0 state.preview_x_scroll)
    (faith.= true state.skip_next_draw?)
    (faith.= 0 state.files_x_scroll)))

(fn test-preview-page-scroll-sets-skip-draw-when-clamped []
  (let [selected (entry "M" "a.rb")
        state (state [selected])
        key (preview-key.for-entry "HEAD" selected)]
    (set state.preview_rows 2)
    (tset state.preview_cache key ["1" "2"])
    (update.update state {} (update.read-msg state "\21"))
    (faith.= true state.skip_next_draw?)))

(fn test-w-toggles-preview-wrap-and-resets-horizontal-scroll []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.preview_wrap? false)
    (set state.preview_x_scroll 8)
    (set state.preview_x_max_scroll 12)
    (update.update state {} (update.read-msg state "w"))
    (faith.= true state.preview_wrap?)
    (faith.= 0 state.preview_x_scroll)
    (faith.= 0 state.preview_x_max_scroll)
    (update.update state {} (update.read-msg state "w"))
    (faith.= false state.preview_wrap?)))

(fn test-b-toggles-blame-and-resets-preview-layout []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.preview_display_cache {:stale true})
    (set state.split_display_cache {:stale true})
    (set state.preview_x_scroll 8)
    (set state.preview_x_max_scroll 12)
    (update.update state {} (update.read-msg state "b"))
    (faith.= true state.show_blame?)
    (faith.= nil state.preview_display_cache)
    (faith.= nil state.split_display_cache)
    (faith.= 0 state.preview_x_scroll)
    (faith.= 0 state.preview_x_max_scroll)
    (update.update state {} (update.read-msg state "b"))
    (faith.= false state.show_blame?)))

(fn test-f-toggles-full-context-globally-across-navigation []
  (let [state (state [(entry "M" "a.rb") (entry "M" "b.rb")])]
    (faith.= false state.full_context?)
    (update.update state {} (update.read-msg state "c"))
    (faith.= true state.full_context?)
    (update.update state {} (update.read-msg state "c"))
    (faith.= false state.full_context?)
    (update.update state {} (update.read-msg state "c"))
    (faith.= true state.full_context?)
    (update.update state {} (update.read-msg state "j"))
    (faith.= true state.full_context?)))

(fn test-tab-toggles-focus-between-panes []
  (let [state (state [(entry "M" "a.rb")])]
    (faith.= :left state.focus)
    (update.update state {} (update.read-msg state "\t"))
    (faith.= :right state.focus)
    (faith.= 1 state.preview_cursor)
    (update.update state {} (update.read-msg state "\t"))
    (faith.= :left state.focus)))

(fn test-jk-move-preview-cursor-when-diff-is-focused []
  (let [state (state [(entry "M" "a.rb") (entry "M" "b.rb")])]
    (set state.preview_total 10)
    (set state.preview_rows 5)
    (update.update state {} (update.read-msg state "\t"))
    (faith.= 1 state.preview_cursor)
    (update.update state {} (update.read-msg state "j"))
    (faith.= 2 state.preview_cursor)
    (faith.= 1 state.selected)
    (update.update state {} (update.read-msg state "k"))
    (faith.= 1 state.preview_cursor)
    (faith.= 1 state.selected)))

(fn test-preview-cursor-scrolls-the-diff-into-view []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.preview_total 10)
    (set state.preview_rows 3)
    (update.update state {} (update.read-msg state "\t"))
    (for [_ 1 4]
      (update.update state {} (update.read-msg state "j")))
    (faith.= 5 state.preview_cursor)
    (faith.= 2 state.preview_scroll)))

(fn test-gg-and-G-move-preview-cursor-when-diff-is-focused []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.preview_total 10)
    (set state.preview_rows 3)
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "G"))
    (faith.= 10 state.preview_cursor)
    (faith.= 7 state.preview_scroll)
    (faith.= 1 state.selected)
    (update.update state {} (update.read-msg state "g"))
    (update.update state {} (update.read-msg state "g"))
    (faith.= 1 state.preview_cursor)
    (faith.= 0 state.preview_scroll)))

(fn test-jk-still-move-file-selection-when-files-are-focused []
  (let [state (state [(entry "M" "a.rb") (entry "M" "b.rb")])]
    (faith.= :left state.focus)
    (update.update state {} (update.read-msg state "j"))
    (faith.= 2 state.selected)
    (faith.= 1 state.preview_cursor)))

(fn type-keys [state keys]
  (each [_ ch (ipairs keys)]
    (update.update state {} (update.read-msg state ch))))

(fn diff-state []
  (let [state (state [(entry "M" "a.rb") (entry "M" "b.rb")])]
    (set state.preview_display_cache
         {:display ["alpha" "beta apple" "gamma" "apple pie"]})
    (set state.preview_total 4)
    (set state.preview_rows 4)
    state))

(fn test-right-pane-search-matches-diff-lines-and-moves-the-cursor []
  (let [state (diff-state)]
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "/"))
    (type-keys state ["a" "p" "p" "l" "e"])
    (faith.= "apple" state.preview_search.query)
    (faith.= 2 (length state.preview_search.matches))
    (faith.= 2 state.preview_cursor)
    (faith.= "" state.search.query)
    (faith.= 1 state.selected)
    (update.update state {} (update.read-msg state :enter))
    (update.update state {} (update.read-msg state "n"))
    (faith.= 4 state.preview_cursor)))

(fn test-left-pane-search-leaves-the-preview-search-untouched []
  (let [state (diff-state)]
    (update.update state {} (update.read-msg state "/"))
    (type-keys state ["b" "." "r" "b"])
    (faith.= "b.rb" state.search.query)
    (faith.= 1 (length state.search.matches))
    (faith.= "" state.preview_search.query)
    (faith.= 1 state.preview_cursor)))

(fn test-each-pane-keeps-its-own-search-across-focus-switches []
  (let [state (diff-state)]
    (update.update state {} (update.read-msg state "/"))
    (type-keys state ["a" "." "r" "b"])
    (update.update state {} (update.read-msg state :enter))
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "/"))
    (type-keys state ["a" "p" "p" "l" "e"])
    (update.update state {} (update.read-msg state :enter))
    (update.update state {} (update.read-msg state "\t"))
    (faith.= "a.rb" state.search.query)
    (faith.= "apple" state.preview_search.query)))

(fn test-tab-shows-the-focused-panes-search-status []
  (let [state (diff-state)]
    (update.update state {} (update.read-msg state "/"))
    (type-keys state ["a" "." "r" "b"])
    (update.update state {} (update.read-msg state :enter))
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "/"))
    (type-keys state ["a" "p" "p" "l" "e"])
    (update.update state {} (update.read-msg state :enter))
    (faith.is (string.find state.notice "apple" 1 true))
    (update.update state {} (update.read-msg state "\t"))
    (faith.is (string.find state.notice "a.rb" 1 true))
    (update.update state {} (update.read-msg state "\t"))
    (faith.is (string.find state.notice "apple" 1 true))))

(fn test-command-dispatches-back-through-update []
  (let [state (state [(entry "M" "a.rb")])
        command (fn [dispatch _get-state]
                  (dispatch {:type :copy-path-finished :path "a.rb" :ok? true}))]
    (update.run-command state {} command)
    (faith.= "Copied: a.rb" state.notice)))

(fn test-copy-path-copies-selected-tree-folder-path []
  (let [state (state [(entry "M" "script/a.sh") (entry "M" "spec/b_spec.rb")])]
    (set state.tree_selected_row 1)
    (let [copied []
          old-copy clipboard.copy]
      (set clipboard.copy (fn [path]
                            (table.insert copied path)
                            true))
      (let [(_ command) (update.update state {} (update.read-msg state "y"))
            messages []]
        (command #(table.insert messages $1) (fn [] state))
        (set clipboard.copy old-copy)
        (faith.= ["script/"] copied)
        (faith.= {:type :copy-path-finished :path "script/" :ok? true}
                 (. messages 1))))))

(fn test-shift-y-copies-the-full-path-in-the-left-pane []
  (let [state (state [(entry "M" "script/a.sh")])]
    (set state.repo_root "/repo")
    (set state.tree_selected_row 1)
    (let [copied []
          old-copy clipboard.copy]
      (set clipboard.copy (fn [path]
                            (table.insert copied path)
                            true))
      (let [(_ command) (update.update state {} (update.read-msg state "Y"))]
        (command #nil (fn [] state))
        (set clipboard.copy old-copy)
        (faith.= ["/repo/script/"] copied)))))

(fn test-shift-y-yanks-the-selection-with-path-and-fences []
  (let [state (diff-state)
        copied []
        old-copy clipboard.copy]
    (set clipboard.copy (fn [text]
                          (table.insert copied text)
                          true))
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "v"))
    (update.update state {} (update.read-msg state "j"))
    (let [(_ command) (update.update state {} (update.read-msg state "Y"))
          messages []]
      (command #(table.insert messages $1) (fn [] state))
      (set clipboard.copy old-copy)
      (faith.= ["a.rb\n\n```\nalpha\nbeta apple\n```"] copied)
      (faith.= nil state.preview_selection_anchor)
      (faith.= {:type :yank-fenced-finished :path "a.rb" :count 2 :ok? true}
               (. messages 1)))))

(fn test-v-starts-and-exits-line-selection-in-right-pane []
  (let [state (diff-state)]
    (update.update state {} (update.read-msg state "\t"))
    (faith.= nil state.preview_selection_anchor)
    (update.update state {} (update.read-msg state "v"))
    (faith.= 1 state.preview_selection_anchor)
    (update.update state {} (update.read-msg state "v"))
    (faith.= nil state.preview_selection_anchor)))

(fn test-v-is-ignored-when-files-are-focused []
  (let [state (diff-state)]
    (faith.= :left state.focus)
    (update.update state {} (update.read-msg state "v"))
    (faith.= nil state.preview_selection_anchor)))

(fn test-q-exits-line-selection-before-clearing-search []
  (let [state (diff-state)]
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "v"))
    (faith.= 1 state.preview_selection_anchor)
    (update.update state {} (update.read-msg state "q"))
    (faith.= nil state.preview_selection_anchor)))

(fn test-tab-back-to-files-clears-line-selection []
  (let [state (diff-state)]
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "v"))
    (faith.= 1 state.preview_selection_anchor)
    (update.update state {} (update.read-msg state "\t"))
    (faith.= nil state.preview_selection_anchor)))

(fn test-y-yanks-the-selected-diff-lines []
  (let [state (diff-state)
        copied []
        old-copy clipboard.copy]
    (set clipboard.copy (fn [text]
                          (table.insert copied text)
                          true))
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "v"))
    (update.update state {} (update.read-msg state "j"))
    (let [(_ command) (update.update state {} (update.read-msg state "y"))
          messages []]
      (command #(table.insert messages $1) (fn [] state))
      (set clipboard.copy old-copy)
      (faith.= ["alpha\nbeta apple"] copied)
      (faith.= nil state.preview_selection_anchor)
      (faith.= {:type :yank-finished :count 2 :ok? true} (. messages 1)))))

(fn test-y-yanks-the-cursor-line-without-a-selection []
  (let [state (diff-state)
        copied []
        old-copy clipboard.copy]
    (set clipboard.copy (fn [text]
                          (table.insert copied text)
                          true))
    (update.update state {} (update.read-msg state "\t"))
    (let [(_ command) (update.update state {} (update.read-msg state "y"))]
      (command #nil (fn [] state))
      (set clipboard.copy old-copy)
      (faith.= ["alpha"] copied))))

(fn wrapped-diff-state []
  (let [state (diff-state)]
    (set state.preview_display_cache
         {:display ["alpha↪" "beta" "gamma"]
          :source ["alphabeta" "gamma"]
          :source-map [1 1 2]})
    (set state.preview_total 3)
    state))

(fn test-y-yanks-one-line-for-a-wrapped-selection []
  (let [state (wrapped-diff-state)
        copied []
        old-copy clipboard.copy]
    (set clipboard.copy (fn [text]
                          (table.insert copied text)
                          true))
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "v"))
    (update.update state {} (update.read-msg state "j"))
    (let [(_ command) (update.update state {} (update.read-msg state "y"))
          messages []]
      (command #(table.insert messages $1) (fn [] state))
      (set clipboard.copy old-copy)
      (faith.= ["alphabeta"] copied)
      (faith.= {:type :yank-finished :count 1 :ok? true} (. messages 1)))))

(fn split-rows []
  [{:kind :change :old "old1" :new "new1"}
   {:kind :change :old "old2" :new "new2"}])

(fn split-state []
  (let [selected (entry "M" "a.rb")
        state (state [selected])
        rows (split-rows)]
    (set state.split_mode? true)
    (tset state.split_cache (.. (preview-key.for-entry "HEAD" selected)
                                "\0split") rows)
    (set state.split_rows rows)
    (set state.preview_total 2)
    (set state.preview_rows 2)
    state))

(fn test-s-toggles-split-mode []
  (let [state (state [(entry "M" "a.rb")])]
    (faith.= true state.split_mode?)
    (update.update state {} (update.read-msg state "s"))
    (faith.= false state.split_mode?)
    (update.update state {} (update.read-msg state "s"))
    (faith.= true state.split_mode?)))

(fn test-tab-cycles-left-old-new-left-in-split []
  (let [state (split-state)]
    (faith.= :left state.focus)
    (update.update state {} (update.read-msg state "\t"))
    (faith.= :right state.focus)
    (faith.= :old state.split_side)
    (update.update state {} (update.read-msg state "\t"))
    (faith.= :right state.focus)
    (faith.= :new state.split_side)
    (update.update state {} (update.read-msg state "\t"))
    (faith.= :left state.focus)))

(fn test-shift-tab-cycles-left-new-old-left-in-split []
  (let [state (split-state)]
    (faith.= :left state.focus)
    (update.update state {} (update.read-msg state :back-tab))
    (faith.= :right state.focus)
    (faith.= :new state.split_side)
    (update.update state {} (update.read-msg state :back-tab))
    (faith.= :right state.focus)
    (faith.= :old state.split_side)
    (update.update state {} (update.read-msg state :back-tab))
    (faith.= :left state.focus)))

(fn test-yank-copies-the-focused-split-column []
  (let [state (split-state)
        copied []
        old-copy clipboard.copy]
    (set clipboard.copy (fn [text]
                          (table.insert copied text)
                          true))
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "v"))
    (update.update state {} (update.read-msg state "j"))
    (let [(_ command) (update.update state {} (update.read-msg state "y"))]
      (command #nil (fn [] state)))
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "v"))
    (let [(_ command) (update.update state {} (update.read-msg state "y"))]
      (command #nil (fn [] state)))
    (set clipboard.copy old-copy)
    (faith.= ["old1\nold2" "new2"] copied)))

(fn test-yank-collapses-wrapped-split-rows []
  (let [state (split-state)
        copied []
        old-copy clipboard.copy]
    (set state.split_logical_rows (split-rows))
    (set state.split_source_map [1 1 2])
    (set state.split_rows
         [{:kind :change :old "old" :new "ne"}
          {:kind :change :old nil :new "w1"}
          {:kind :change :old "old2" :new "new2"}])
    (set state.preview_total 3)
    (set state.preview_rows 3)
    (set clipboard.copy (fn [text]
                          (table.insert copied text)
                          true))
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "v"))
    (update.update state {} (update.read-msg state "j"))
    (update.update state {} (update.read-msg state "j"))
    (let [(_ command) (update.update state {} (update.read-msg state "y"))]
      (command #nil (fn [] state)))
    (set clipboard.copy old-copy)
    (faith.= ["old1\nold2"] copied)))

(fn test-split-search-is-scoped-to-the-focused-side []
  (let [state (split-state)]
    (update.update state {} (update.read-msg state "\t"))
    (update.update state {} (update.read-msg state "/"))
    (type-keys state ["o" "l" "d"])
    (faith.= 2 (length state.preview_search.matches))
    (update.update state {} (update.read-msg state :enter))
    (update.update state {} (update.read-msg state "\t"))
    (faith.= :new state.split_side)
    (faith.= 0 (length state.preview_search.matches))
    (update.update state {} (update.read-msg state "/"))
    (type-keys state ["n" "e" "w" "2"])
    (faith.= 1 (length state.preview_search.matches))
    (faith.= 2 state.preview_cursor)))

(fn test-yank-finished-updates-notice []
  (let [state (state [(entry "M" "a.rb")])]
    (update.update state {} {:type :yank-finished :count 1 :ok? true})
    (faith.= "Copied 1 line" state.notice)
    (update.update state {} {:type :yank-finished :count 3 :ok? true})
    (faith.= "Copied 3 lines" state.notice)))

(fn test-open-pr-finished-updates-notice []
  (let [state (state [(entry "M" "a.rb")])]
    (update.update state {}
                   {:type :open-pr-finished
                    :ok? true
                    :url "https://example.com/pull/1"})
    (faith.= "Opened PR: https://example.com/pull/1" state.notice)
    (update.update state {}
                   {:type :open-pr-finished
                    :ok? false
                    :error "No linked PR for feature"})
    (faith.= "No linked PR for feature" state.notice)))

(fn test-open-target-finished-updates-notice []
  (let [state (state [(entry "M" "a.rb")])]
    (update.update state {} {:type :open-target-finished
                             :target :folder
                             :path "src"
                             :ok? true})
    (faith.= "Opening: src" state.notice)
    (update.update state {} {:type :open-target-finished
                             :target :folder
                             :path "missing"
                             :ok? false})
    (faith.= "Folder not found: missing" state.notice)
    (update.update state {} {:type :open-target-finished
                             :target :file
                             :path "missing.rb"
                             :ok? false})
    (faith.= "File not found: missing.rb" state.notice)))

{: test-f-toggles-full-context-globally-across-navigation
 : test-tab-toggles-focus-between-panes
 : test-jk-move-preview-cursor-when-diff-is-focused
 : test-preview-cursor-scrolls-the-diff-into-view
 : test-gg-and-G-move-preview-cursor-when-diff-is-focused
 : test-jk-still-move-file-selection-when-files-are-focused
 : test-right-pane-search-matches-diff-lines-and-moves-the-cursor
 : test-left-pane-search-leaves-the-preview-search-untouched
 : test-each-pane-keeps-its-own-search-across-focus-switches
 : test-tab-shows-the-focused-panes-search-status
 : test-command-dispatches-back-through-update
 : test-copy-path-copies-selected-tree-folder-path
 : test-h-l-scroll-preview-horizontally
 : test-local-refresh-does-not-start-remote-sync
 : test-refresh-keeps-preview-cursor-when-diff-focused
 : test-refresh-resets-preview-cursor-when-files-focused
 : test-refresh-keeps-preview-scroll-when-files-focused
 : test-refresh-clears-stale-preview-cache
 : test-lowercase-r-refreshes-files-and-starts-sync
 : test-shift-y-copies-the-full-path-in-the-left-pane
 : test-shift-y-yanks-the-selection-with-path-and-fences
 : test-v-starts-and-exits-line-selection-in-right-pane
 : test-v-is-ignored-when-files-are-focused
 : test-q-exits-line-selection-before-clearing-search
 : test-tab-back-to-files-clears-line-selection
 : test-y-yanks-the-selected-diff-lines
 : test-y-yanks-the-cursor-line-without-a-selection
 : test-y-yanks-one-line-for-a-wrapped-selection
 : test-s-toggles-split-mode
 : test-tab-cycles-left-old-new-left-in-split
 : test-shift-tab-cycles-left-new-old-left-in-split
 : test-yank-copies-the-focused-split-column
 : test-yank-collapses-wrapped-split-rows
 : test-split-search-is-scoped-to-the-focused-side
 : test-yank-finished-updates-notice
 : test-open-pr-finished-updates-notice
 : test-open-target-finished-updates-notice
 : test-preview-page-scroll-sets-skip-draw-when-clamped
 : test-read-msg-keeps-pending-g-in-state
 : test-read-msg-turns-raw-key-into-message-data
 : test-start-command-starts-remote-sync-quietly
 : test-split-keys-move-divider-by-five-percent
 : test-split-ratio-is-clamped
 : test-uppercase-r-does-not-attach-to-startup-sync
 : test-uppercase-r-does-not-start-sync
 : test-unknown-key-clears-pending-g
 : test-b-toggles-blame-and-resets-preview-layout
 : test-w-toggles-preview-wrap-and-resets-horizontal-scroll
 : test-update-returns-command-for-review-persistence}
