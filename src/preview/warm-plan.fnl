(local preview-key (require :preview.key))
(local workers (require :preview.workers))

(local edge-batch-size 8)

(fn missing-entries [revision entries cache]
  (let [cache (or cache {})]
    (icollect [_ entry (ipairs entries)]
      (when (not (. cache (preview-key.for-entry revision entry)))
        entry))))

(fn side-priority-entries [entries ?batch-size]
  (let [batch-size (or ?batch-size edge-batch-size)
        out []]
    (var left 1)
    (var right (length entries))
    (while (<= left right)
      (var front-count 0)
      (while (and (<= left right) (< front-count batch-size))
        (table.insert out (. entries left))
        (set left (+ left 1))
        (set front-count (+ front-count 1)))
      (var back-count 0)
      (while (and (<= left right) (< back-count batch-size))
        (table.insert out (. entries right))
        (set right (- right 1))
        (set back-count (+ back-count 1))))
    out))

(fn index-entries [revision entries]
  (let [indexes {}
        keys {}]
    (each [i entry (ipairs entries)]
      (let [entry-key (preview-key.for-entry revision entry)]
        (tset indexes entry-key i)
        (tset keys i entry-key)))
    (values indexes keys)))

(fn worker-count [entries ?cpu-count]
  (workers.count entries ?cpu-count))

{: index-entries : missing-entries : side-priority-entries : worker-count}
