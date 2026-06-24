(local facade (require :app.search-facade))
(local matcher (require :app.search-match))
(local selection (require :app.selection))

(local context
       {:get (fn [state] state.search)
        :set (fn [state search] (set state.search search))
        :cursor-position (fn [state] (selection.cursor-position state))
        :collect (fn [state query] (matcher.collect-matches state query))
        :apply (fn [state found] (selection.set-match state found))})

(facade.build context)
