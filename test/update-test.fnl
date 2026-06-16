(local faith (require :faith))
(local reviews (require :reviews))
(local update (require :update))

(fn entry [status path]
  {:status status :kind (status:sub 1 1) :path path :reviewed false})

(fn state [entries]
  (let [state (update.init "HEAD" entries {:version 1 :reviews {}} "scope"
                           "src")]
    (set state.sync.next_at (+ (os.time) 999))
    state))

(fn test-read-msg-turns-raw-key-into-message-data []
  (let [state (state [(entry "M" "a.rb")])]
    (faith.= {:type :key :action :toggle-all-reviewed}
             (update.read-msg state "a"))))

(fn test-update-returns-command-for-review-persistence []
  (let [state (state [(entry "M" "a.rb")])
        (_ command) (update.update state {}
                                   {:type :key :action :toggle-all-reviewed})]
    (faith.= {"a.rb" true} (reviews.paths state.entries))
    (faith.= "Marked all reviewed" state.notice)
    (faith.= :function (type command))))

(fn test-command-dispatches-back-through-update []
  (let [state (state [(entry "M" "a.rb")])
        command (fn [dispatch _get-state]
                  (dispatch {:type :copy-path-finished :path "a.rb" :ok? true}))]
    (update.run-command state {} command)
    (faith.= "Copied: a.rb" state.notice)))

{: test-command-dispatches-back-through-update
 : test-read-msg-turns-raw-key-into-message-data
 : test-update-returns-command-for-review-persistence}
