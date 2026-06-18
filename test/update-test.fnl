(local faith (require :faith))
(local clipboard (require :platform.clipboard))
(local preview-key (require :preview.key))
(local reviews (require :storage.reviews))
(local update (require :app.update))

(fn entry [status path]
  {:status status :kind (status:sub 1 1) :path path :reviewed false})

(fn state [entries]
  (let [state (update.init "HEAD" entries {:version 1 :reviews {}} "scope"
                           "src")]
    (set state.sync.next_at (+ (os.time) 999))
    state))

(fn test-read-msg-turns-raw-key-into-message-data []
  (let [state (state [(entry "M" "a.rb")])]
    (faith.= {:type :toggle-all-reviewed} (update.read-msg state "a"))
    (faith.= {:type :toggle-wrap} (update.read-msg state "w"))
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

(fn test-local-refresh_does_not_start_remote_sync []
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

(fn test-h_l_scroll_preview_horizontally []
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

(fn test-preview_page_scroll_sets_skip_draw_when_clamped []
  (let [selected (entry "M" "a.rb")
        state (state [selected])
        key (preview-key.for-entry "HEAD" selected)]
    (set state.preview_rows 2)
    (tset state.preview_cache key ["1" "2"])
    (update.update state {} (update.read-msg state "\21"))
    (faith.= true state.skip_next_draw?)))

(fn test-w_toggles_preview_wrap_and_resets_horizontal_scroll []
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

(fn test-command-dispatches-back-through-update []
  (let [state (state [(entry "M" "a.rb")])
        command (fn [dispatch _get-state]
                  (dispatch {:type :copy-path-finished :path "a.rb" :ok? true}))]
    (update.run-command state {} command)
    (faith.= "Copied: a.rb" state.notice)))

(fn test-copy-path-copies_selected_tree_folder_path []
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

{: test-command-dispatches-back-through-update
 : test-copy-path-copies_selected_tree_folder_path
 : test-h_l_scroll_preview_horizontally
 : test-local-refresh_does_not_start_remote_sync
 : test-lowercase-r-refreshes-files-and-starts-sync
 : test-open-pr-finished-updates-notice
 : test-open-target-finished-updates-notice
 : test-preview_page_scroll_sets_skip_draw_when_clamped
 : test-read-msg-keeps-pending-g-in-state
 : test-read-msg-turns-raw-key-into-message-data
 : test-start-command-starts-remote-sync-quietly
 : test-split-keys-move-divider-by-five-percent
 : test-split-ratio-is-clamped
 : test-uppercase-r-does-not-attach-to-startup-sync
 : test-uppercase-r-does-not-start-sync
 : test-unknown-key-clears-pending-g
 : test-w_toggles_preview_wrap_and_resets_horizontal_scroll
 : test-update-returns-command-for-review-persistence}
