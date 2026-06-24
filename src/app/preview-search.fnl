(local facade (require :app.search-facade))
(local matcher (require :app.preview-search-match))
(local preview (require :preview.core))

(local context
       {:get (fn [state] state.preview_search)
        :set (fn [state search] (set state.preview_search search))
        :cursor-position (fn [state] (or state.preview_cursor 1))
        :collect (fn [state query] (matcher.collect-matches state query))
        :apply (fn [state found] (preview.cursor-jump state found.line))})

(facade.build context)
