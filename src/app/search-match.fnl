(local entry-view (require :app.entry))
(local line-matcher (require :app.preview-search-match))
(local selection (require :app.selection))
(local str (require :util.string))

(local contains? str.contains?)

(fn path-match [query entry-index entry]
  (if (contains? (entry-view.path-text entry) query)
      {:entry entry-index}))

(fn tree-label [row]
  (if (= row.type :folder)
      row.name
      (or row.name (entry-view.path-text row.entry))))

(fn tree-path [row]
  (if (= row.type :folder)
      row.path
      (and row.entry (entry-view.path-text row.entry))))

(fn path-query? [query]
  (not (= nil (string.find query "/" 1 true))))

(fn tree-match [query row-index row]
  (let [needle (str.strip-trailing-slash query)]
    (if (or (contains? (tree-label row) query)
            (and (path-query? query) (< 0 (length needle))
                 (contains? (tree-path row) needle)))
        {:tree-row row-index :entry row.entry-index})))

(fn line-matches [state query row-index entry]
  (icollect [_ found (ipairs (line-matcher.collect-matches state entry query))]
    {:row row-index :line found.line :side found.side}))

(fn add-row [matches state query row-index entry ?found]
  (when ?found
    (table.insert matches ?found))
  (when entry
    (each [_ found (ipairs (line-matches state query row-index entry))]
      (table.insert matches found))))

(fn collect-matches [state query]
  "Collect file rows whose name matches, in list order, each followed by the
matching lines of that file's cached preview."
  (let [matches []]
    (when (> (length query) 0)
      (if (= state.view_mode :tree)
          (each [row-index row (ipairs (selection.tree-rows state))]
            (add-row matches state query row-index row.entry
                     (tree-match query row-index row)))
          (each [entry-index entry (ipairs state.entries)]
            (add-row matches state query entry-index entry
                     (path-match query entry-index entry)))))
    matches))

{: collect-matches : path-match : tree-label : tree-match : tree-path}
