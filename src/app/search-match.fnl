(local entry-view (require :app.entry))
(local selection (require :app.selection))

(fn contains? [text query]
  (let [text (or text "")]
    (not (= nil (text:find query 1 true)))))

(fn path-match [query entry-index entry]
  (if (contains? (entry-view.path-text entry) query)
      {:entry entry-index}))

(fn tree-label [row]
  (if (= row.type :folder)
      row.name
      (or row.name (entry-view.path-text row.entry))))

(fn tree-match [query row-index row]
  (if (contains? (tree-label row) query)
      {:tree-row row-index :entry row.entry-index}))

(fn collect-matches [state query]
  (let [matches []]
    (when (> (length query) 0)
      (if (= state.view_mode :tree)
          (each [row-index row (ipairs (selection.tree-rows state))]
            (let [found (tree-match query row-index row)]
              (when found
                (table.insert matches found))))
          (each [entry-index entry (ipairs state.entries)]
            (let [found (path-match query entry-index entry)]
              (when found
                (table.insert matches found))))))
    matches))

{: collect-matches : contains? : path-match : tree-label : tree-match}
