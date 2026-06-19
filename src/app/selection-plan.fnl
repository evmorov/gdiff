(local math-util (require :util.math))

(fn flat-index [entries selected delta]
  (if (= (length entries) 0)
      1
      (math-util.clamp (+ selected delta) 1 (length entries))))

(fn changed? [before after]
  (not (= before after)))

(fn selected-row-index [view-mode tree-selected-row selected fallback-tree-row]
  (if (= view-mode :tree)
      (or tree-selected-row fallback-tree-row)
      selected))

{: changed? : flat-index : selected-row-index}
