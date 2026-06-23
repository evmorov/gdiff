(local preview (require :preview.core))
(local tui (require :tui.core))

(fn contains? [text query]
  (let [text (or text "")]
    (not (= nil (text:find query 1 true)))))

(fn collect-matches [state query]
  (let [matches []
        lines (preview.display-lines state)]
    (when (> (length query) 0)
      (each [index line (ipairs lines)]
        (when (contains? (tui.strip-ansi line) query)
          (table.insert matches {:line index}))))
    matches))

{: collect-matches : contains?}
