(local faith (require :faith))
(local facade (require :app.search-facade))
(local search (require :app.search))
(local preview-search (require :app.preview-search))

(local expected-api [:active?
                     :clear
                     :handle-input
                     :has-query?
                     :highlight
                     :new-state
                     :next
                     :previous
                     :query
                     :rebuild
                     :refresh-status
                     :start
                     :status])

(fn assert-api [module]
  (each [_ name (ipairs expected-api)]
    (faith.= :function (type (. module name)) (.. name " should be a function"))))

(fn test-file-search-exposes-full-api []
  (assert-api search))

(fn test-preview-search-exposes-full-api []
  (assert-api preview-search))

(fn test-build-threads-context-through-engine []
  (let [context {:get (fn [state] state.search)
                 :set (fn [state s] (set state.search s))
                 :cursor-position (fn [_state] 1)
                 :collect (fn [_state _query] [])
                 :apply (fn [_state _found] nil)}
        module (facade.build context)
        state {}]
    (assert-api module)
    (faith.= "" (. (module.new-state) :query))
    (faith.is (not (module.active? state)))
    (module.start state)
    (faith.is (module.active? state))
    (faith.is (not (module.has-query? state)))
    (module.handle-input state "x")
    (faith.= "x" (module.query state))
    (module.handle-input state {:paste "yz"})
    (faith.= "xyz" (module.query state))
    (module.clear state)
    (faith.is (not (module.has-query? state)))))

{: test-file-search-exposes-full-api
 : test-preview-search-exposes-full-api
 : test-build-threads-context-through-engine}
