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
    (faith.= {:type :toggle-all-reviewed} (update.read-msg state "a"))))

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

{: test-command-dispatches-back-through-update
 : test-read-msg-keeps-pending-g-in-state
 : test-read-msg-turns-raw-key-into-message-data
 : test-split-keys-move-divider-by-five-percent
 : test-split-ratio-is-clamped
 : test-unknown-key-clears-pending-g
 : test-update-returns-command-for-review-persistence}
