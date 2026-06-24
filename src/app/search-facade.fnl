(local engine (require :app.search-engine))
(local search-plan (require :app.search-plan))

(fn build [context]
  {:active? (fn [state] (engine.active? context state))
   :clear (fn [state] (engine.clear context state))
   :handle-input (fn [state key] (engine.handle-input context state key))
   :has-query? (fn [state] (engine.has-query? context state))
   :highlight (fn [state text] (engine.highlight context state text))
   :new-state (fn [] (search-plan.new-state))
   :next (fn [state] (engine.next context state))
   :previous (fn [state] (engine.previous context state))
   :query (fn [state] (engine.query context state))
   :rebuild (fn [state ?preserve-selection?]
              (engine.rebuild context state ?preserve-selection?))
   :refresh-status (fn [state] (engine.refresh-status context state))
   :start (fn [state] (engine.start context state))
   :status (fn [state] (engine.status context state))})

{: build}
