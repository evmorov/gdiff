(local app (require :app.core))
(local faith (require :faith))
(local reviews (require :storage.reviews))
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

(fn test-split-key-does-not-start-due-sync []
  (let [state (state [(entry "M" "a.rb")])]
    (set state.sync.next_at 0)
    (faith.is (app.handle-key state {} ">"))
    (faith.= false state.sync.running?)
    (faith.almost= 0.45 state.split_ratio 0.0001)))

{: test-a-toggles-all-reviewed-and-A-does-nothing
 : test-search-next-is-relative-to-current-cursor
 : test-split-key-does-not-start-due-sync
 : test-view-renders-renames-with-short-status}
