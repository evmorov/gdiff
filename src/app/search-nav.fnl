(fn position [found]
  (or found.tree-row found.entry found.line))

(fn first-at-or-after [cursor matches]
  (var index 1)
  (var found? false)
  (each [i found (ipairs matches)]
    (when (and (not found?) (>= (position found) cursor))
      (set index i)
      (set found? true)))
  index)

(fn first-after [cursor matches]
  (var index 1)
  (var found? false)
  (each [i found (ipairs matches)]
    (when (and (not found?) (> (position found) cursor))
      (set index i)
      (set found? true)))
  index)

(fn last-before [cursor matches]
  (let [count (length matches)]
    (var index count)
    (var found? false)
    (for [i count 1 -1]
      (let [found (. matches i)]
        (when (and found (not found?) (< (position found) cursor))
          (set index i)
          (set found? true))))
    index))

{: first-after : first-at-or-after : last-before : position}
