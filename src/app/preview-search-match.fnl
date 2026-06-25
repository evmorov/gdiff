(local preview (require :preview.core))
(local tui (require :tui.core))
(local str (require :util.string))

(local contains? str.contains?)

(fn split-matches [state query]
  (let [matches []
        side (or state.split_side :old)]
    (each [index row (ipairs (or state.split_rows []))]
      (let [value (. row side)]
        (when (and value (contains? value query))
          (table.insert matches {:line index}))))
    matches))

(fn unified-matches [state query]
  (let [matches []
        lines (preview.display-lines state)]
    (each [index line (ipairs lines)]
      (when (contains? (tui.strip-ansi line) query)
        (table.insert matches {:line index})))
    matches))

(fn collect-matches [state query]
  (if (= 0 (length query)) []
      (preview.split-active? state) (split-matches state query)
      (unified-matches state query)))

{: collect-matches : contains?}
