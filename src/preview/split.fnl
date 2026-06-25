(local word-diff (require :preview.word-diff))

(fn classify [line in-hunk?]
  (let [first (line:sub 1 1)]
    (if (line:match "^diff ") :file
        (line:match "^@@") :hunk
        (not in-hunk?) :meta
        (= first "+") :added
        (= first "-") :removed
        (= first "\\") :marker
        :context)))

(fn ordered-pairs [pairs]
  (let [out []]
    (var pend-old [])
    (var pend-new [])

    (fn drain []
      (each [_ p (ipairs pend-old)]
        (table.insert out p))
      (each [_ p (ipairs pend-new)]
        (table.insert out p))
      (set pend-old [])
      (set pend-new []))

    (each [_ p (ipairs pairs)]
      (if (and p.old p.new) (do
                              (drain)
                              (table.insert out p))
          p.old (table.insert pend-old p)
          (table.insert pend-new p)))
    (drain)
    out))

(fn flush [acc]
  (each [_ p (ipairs (ordered-pairs (word-diff.align acc.removed acc.added)))]
    (let [old (and p.old (. acc.removed p.old))
          new (and p.new (. acc.added p.new))
          row {:kind :change : old : new}]
      (when (and p.old p.new) (set row.emphasize? true))
      (table.insert acc.rows row)))
  (set acc.removed [])
  (set acc.added []))

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
