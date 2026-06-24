(local engine (require :app.search-engine))
(local search-plan (require :app.search-plan))

(fn build [context]
  {:active? #(engine.active? context $)
   :clear #(engine.clear context $)
   :handle-input #(engine.handle-input context $1 $2)
   :has-query? #(engine.has-query? context $)
   :highlight #(engine.highlight context $1 $2)
   :new-state #(search-plan.new-state)
   :next #(engine.next context $)
   :previous #(engine.previous context $)
   :query #(engine.query context $)
   :rebuild #(engine.rebuild context $1 $2)
   :refresh-status #(engine.refresh-status context $)
   :start #(engine.start context $)
   :status #(engine.status context $)})

{: build}
