(local math-util (require :util.math))

(fn flat-index [entries selected delta]
  (if (= (length entries) 0)
      1
      (math-util.clamp (+ selected delta) 1 (length entries))))

(fn changed? [before after]
  (not (= before after)))

{: changed? : flat-index}
