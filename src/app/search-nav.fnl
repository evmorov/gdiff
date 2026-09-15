(fn row-of [found]
  (or found.tree-row found.row found.entry))

(fn line-of [found]
  (or found.line 0))

(fn before? [a b]
  (let [row-a (row-of a)
        row-b (row-of b)]
    (or (< row-a row-b) (and (= row-a row-b) (< (line-of a) (line-of b))))))

(fn first-where [matches pred]
  (accumulate [index nil i found (ipairs matches) &until index]
    (when (pred found) i)))

(fn last-where [matches pred]
  (faccumulate [index nil i (length matches) 1 -1 &until index]
    (when (pred (. matches i)) i)))

(fn first-at-or-after [cursor matches]
  (or (first-where matches #(not (before? $ cursor))) 1))

(fn first-after [cursor matches]
  (or (first-where matches #(before? cursor $)) 1))

(fn last-before [cursor matches]
  (or (last-where matches #(before? $ cursor)) (length matches)))

(fn same-place? [a b]
  (and (= (row-of a) (row-of b)) (= (line-of a) (line-of b))))

(fn index-of [matches found]
  (first-where matches #(same-place? $ found)))

{: before? : first-after : first-at-or-after : last-before : index-of : row-of}
