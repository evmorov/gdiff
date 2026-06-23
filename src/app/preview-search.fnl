(local engine (require :app.search-engine))
(local matcher (require :app.preview-search-match))
(local preview (require :preview.core))
(local search-plan (require :app.search-plan))

(local context
       {:get (fn [state] state.preview_search)
        :set (fn [state search] (set state.preview_search search))
        :cursor-position (fn [state] (or state.preview_cursor 1))
        :collect (fn [state query] (matcher.collect-matches state query))
        :apply (fn [state found] (preview.cursor-jump state found.line))})

(fn new-state []
  (search-plan.new-state))

(fn active? [state]
  (engine.active? context state))

(fn has-query? [state]
  (engine.has-query? context state))

(fn query [state]
  (engine.query context state))

(fn start [state]
  (engine.start context state))

(fn clear [state]
  (engine.clear context state))

(fn rebuild [state ?preserve-selection?]
  (engine.rebuild context state ?preserve-selection?))

(fn handle-input [state key]
  (engine.handle-input context state key))

(fn next [state]
  (engine.next context state))

(fn previous [state]
  (engine.previous context state))

(fn highlight [state text]
  (engine.highlight context state text))

(fn status [state]
  (engine.status context state))

(fn refresh-status [state]
  (engine.refresh-status context state))

{: active?
 : clear
 : handle-input
 : has-query?
 : highlight
 : new-state
 : next
 : previous
 : query
 : rebuild
 : refresh-status
 : start
 : status}
