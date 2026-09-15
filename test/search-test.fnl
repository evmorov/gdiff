(local faith (require :faith))
(local search (require :app.search))

(fn test-label-query-keeps-plain-query []
  (faith.= "app" (search.label-query "app.fnl" "app")))

(fn test-label-query-keeps-path-when-present-in-text []
  (faith.= "src/app" (search.label-query "src/app/" "src/app"))
  (faith.= "src/app/view.fnl"
           (search.label-query "src/app/view.fnl" "src/app/view.fnl")))

(fn test-label-query-falls-back-to-trailing-segment-for-basename []
  (faith.= "view.fnl" (search.label-query "view.fnl" "src/app/view.fnl"))
  (faith.= "vie" (search.label-query "view.fnl" "src/app/vie")))

(fn test-label-query-handles-folder-path-with-trailing-slash []
  (faith.= "app" (search.label-query "app/" "src/app/"))
  (faith.= "src/app" (search.label-query "src/app/" "src/app/")))

(fn test-input-edits-the-query-and-clears-on-escape []
  (let [state {:search (search.new-state) :entries [] :view_mode :flat}]
    (faith.is (not (search.active? state)))
    (search.start state)
    (faith.is (search.active? state))
    (search.handle-input state "x")
    (faith.= "x" (search.query state))
    (search.handle-input state {:paste "yz"})
    (faith.= "xyz" (search.query state))
    (search.handle-input state "\127")
    (faith.= "xy" (search.query state))
    (search.handle-input state :enter)
    (faith.is (not (search.active? state)))
    (faith.is (search.has-query? state))
    (search.handle-input state :escape)
    (faith.is (not (search.has-query? state)))))

{: test-label-query-keeps-plain-query
 : test-label-query-keeps-path-when-present-in-text
 : test-label-query-falls-back-to-trailing-segment-for-basename
 : test-label-query-handles-folder-path-with-trailing-slash
 : test-input-edits-the-query-and-clears-on-escape}
