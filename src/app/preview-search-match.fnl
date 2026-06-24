(local preview (require :preview.core))
(local tui (require :tui.core))
(local str (require :util.string))

(local contains? str.contains?)

(fn collect-matches [state query]
  (let [matches []
        lines (preview.display-lines state)]
    (when (> (length query) 0)
      (each [index line (ipairs lines)]
        (when (contains? (tui.strip-ansi line) query)
          (table.insert matches {:line index}))))
    matches))

{: collect-matches : contains?}
