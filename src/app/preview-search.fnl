(local facade (require :app.search-facade))
(local matcher (require :app.preview-search-match))
(local preview (require :preview.core))

(local context
       {:get (fn [state] state.preview_search)
        :set (fn [state search] (set state.preview_search search))
        :cursor-position (fn [state] (or state.preview_cursor 1))
        :collect (fn [state query] (matcher.collect-matches state query))
        :apply (fn [state found] (preview.cursor-jump state found.line))})

(local preview-search (facade.build context))

(fn sync-search [state display]
  (when (and (= state.focus :right) (preview-search.has-query? state)
             (not (= state.preview_search.matches-source display)))
    (set state.preview_search.matches-source display)
    (preview-search.rebuild state true)))

(set preview-search.sync-search sync-search)

preview-search
