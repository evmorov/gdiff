(local faith (require :faith))
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
    (faith.= {:type :sync} (update.read-msg state "R"))
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

(fn test-uppercase-r_returns_remote_sync_command []
  (let [state (state [(entry "M" "a.rb")])
        (_ command) (update.update state {} (update.read-msg state "R"))]
    (faith.= :function (type command))
    (faith.= "Syncing remote..." state.notice)))

(fn test-uppercase-r-shows-notice-when-startup-sync-is-running []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.sync.running? true)
    (let [(_ command) (update.update state {} (update.read-msg state "R"))]
      (faith.= :function (type command))
      (faith.= "Syncing remote..." state.notice))))

(fn test-start-command-starts-remote-sync-quietly []
  (let [state (state [(entry "M" "a.rb")])
        command (update.start-command state)]
    (faith.= :function (type command))
    (faith.= nil state.notice)))

(fn test-split-keys-move-divider-by-five-percent []
  (let [state (state [(entry "M" "a.rb")])]
    (update.update state {} (update.read-msg state "<"))
    (faith.almost= 0.35 state.split_ratio 0.0001)
    (update.update state {} (update.read-msg state ">"))
    (faith.almost= 0.4 state.split_ratio 0.0001)))

(fn test-split-ratio-is-clamped []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.split_ratio 0.1)
    (update.update state {} (update.read-msg state "<"))
    (faith.= 0.1 state.split_ratio)
    (set state.split_ratio 0.9)
    (update.update state {} (update.read-msg state ">"))
    (faith.= 0.9 state.split_ratio)))

(fn test-command-dispatches-back-through-update []
  (let [state (state [(entry "M" "a.rb")])
        command (fn [dispatch _get-state]
                  (dispatch {:type :copy-path-finished :path "a.rb" :ok? true}))]
    (update.run-command state {} command)
    (faith.= "Copied: a.rb" state.notice)))

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

{: test-command-dispatches-back-through-update
 : test-local-refresh_does_not_start_remote_sync
 : test-lowercase-r-refreshes-files-and-starts-sync
 : test-open-pr-finished-updates-notice
 : test-read-msg-keeps-pending-g-in-state
 : test-read-msg-turns-raw-key-into-message-data
 : test-start-command-starts-remote-sync-quietly
 : test-split-keys-move-divider-by-five-percent
 : test-split-ratio-is-clamped
 : test-uppercase-r-shows-notice-when-startup-sync-is-running
 : test-uppercase-r_returns_remote_sync_command
 : test-unknown-key-clears-pending-g
 : test-update-returns-command-for-review-persistence}
