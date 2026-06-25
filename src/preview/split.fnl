(fn classify [line in-hunk?]
  (let [first (line:sub 1 1)]
    (if (line:match "^diff ") :file
        (line:match "^@@") :hunk
        (not in-hunk?) :meta
        (= first "+") :added
        (= first "-") :removed
        (= first "\\") :marker
        :context)))

(fn flush [acc]
  (let [n (math.max (length acc.removed) (length acc.added))]
    (for [i 1 n]
      (table.insert acc.rows
                    {:kind :change :old (. acc.removed i) :new (. acc.added i)}))
    (set acc.removed [])
    (set acc.added [])))

(fn full-row [acc kind line]
  (table.insert acc.rows {: kind :old line :new line}))

(fn step [acc line]
  (case (classify line acc.in-hunk?)
    :file (do
            (flush acc) (set acc.in-hunk? false)
            (full-row acc :meta line))
    :hunk (do
            (flush acc) (set acc.in-hunk? true)
            (full-row acc :hunk line))
    :meta (full-row acc :meta line)
    :added (table.insert acc.added (line:sub 2))
    :removed (table.insert acc.removed (line:sub 2))
    :context (do
               (flush acc)
               (table.insert acc.rows
                             {:kind :context
                              :old (line:sub 2)
                              :new (line:sub 2)}))))

(fn parse-rows [text]
  (let [acc {:rows [] :removed [] :added [] :in-hunk? false}]
    (each [line (string.gmatch (or text "") "[^\r\n]+")]
      (step acc line))
    (flush acc)
    acc.rows))

(fn splittable? [rows]
  (accumulate [found false _ row (ipairs (or rows [])) &until found]
    (or (= row.kind :change) (= row.kind :context))))

{: parse-rows : splittable?}
