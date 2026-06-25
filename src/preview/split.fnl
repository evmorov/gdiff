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

(fn diff-path [line]
  (let [stripped (line:sub 5)
        trimmed (stripped:gsub "%s+$" "")]
    (if (= trimmed "/dev/null")
        ""
        (or (trimmed:match "^[ab]/(.+)$") trimmed))))

(fn meta-step [acc line]
  (if (line:match "^%-%-%- ") (set acc.old-path (diff-path line))
      (line:match "^%+%+%+ ") (set acc.new-path (diff-path line))))

(fn step [acc line]
  (case (classify line acc.in-hunk?)
    :file (do
            (flush acc)
            (set acc.in-hunk? false))
    :hunk (do
            (flush acc)
            (set acc.in-hunk? true)
            (table.insert acc.rows {:kind :hunk :old line}))
    :meta (meta-step acc line)
    :added (table.insert acc.added (line:sub 2))
    :removed (table.insert acc.removed (line:sub 2))
    :context (do
               (flush acc)
               (table.insert acc.rows
                             {:kind :context
                              :old (line:sub 2)
                              :new (line:sub 2)}))))

(fn has-content? [rows]
  (accumulate [found false _ row (ipairs (or rows [])) &until found]
    (or (= row.kind :change) (= row.kind :context))))

(fn header-path [primary fallback]
  (or (and primary (< 0 (length primary)) primary)
      (and fallback (< 0 (length fallback)) fallback)))

(fn header-title [path ?ref]
  (if (and ?ref (< 0 (length ?ref))) (.. path " (" ?ref ")") path))

(fn prepend-header [acc ?old-ref ?new-ref]
  (let [old-path (header-path acc.old-path acc.new-path)
        new-path (header-path acc.new-path acc.old-path)]
    (when (and old-path (has-content? acc.rows))
      (let [old-title (header-title old-path ?old-ref)
            new-title (header-title new-path ?new-ref)]
        (table.insert acc.rows 1 {:kind :rule :old old-title :new new-title})
        (table.insert acc.rows 1
                      {:kind :filename :old old-title :new new-title})))))

(fn parse-rows [text ?old-ref ?new-ref]
  (let [acc {:rows [] :removed [] :added [] :in-hunk? false}]
    (each [line (string.gmatch (or text "") "[^\r\n]+")]
      (step acc line))
    (flush acc)
    (prepend-header acc ?old-ref ?new-ref)
    acc.rows))

(fn splittable? [rows]
  (has-content? rows))

{: parse-rows : splittable?}
