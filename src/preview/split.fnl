(local word-diff (require :preview.word-diff))
(local diff-parse (require :preview.diff-parse))

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

(fn change-rows [removed added old-no new-no]
  (icollect [_ p (ipairs (ordered-pairs (word-diff.align removed added)))]
    (let [old (and p.old (. removed p.old))
          new (and p.new (. added p.new))
          row {:kind :change
               : old
               : new
               :old-no (and p.old (+ old-no p.old -1))
               :new-no (and p.new (+ new-no p.new -1))}]
      (when (and p.old p.new)
        (set row.emphasize? true)
        (set row.spans (word-diff.spans old new)))
      row)))

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
  (let [acc {:rows [] :old-no 1 :new-no 1}
        handlers {:change (fn [removed added]
                            (each [_ row (ipairs (change-rows removed added
                                                              acc.old-no
                                                              acc.new-no))]
                              (table.insert acc.rows row))
                            (set acc.old-no (+ acc.old-no (length removed)))
                            (set acc.new-no (+ acc.new-no (length added))))
                  :hunk (fn [line]
                          (table.insert acc.rows {:kind :hunk :old line})
                          (let [(old new) (diff-parse.hunk-start line)]
                            (when old (set acc.old-no old))
                            (when new (set acc.new-no new))))
                  :context (fn [text]
                             (table.insert acc.rows
                                           {:kind :context
                                            :old text
                                            :new text
                                            :old-no acc.old-no
                                            :new-no acc.new-no})
                             (set acc.old-no (+ acc.old-no 1))
                             (set acc.new-no (+ acc.new-no 1)))
                  :old-path (fn [path] (set acc.old-path path))
                  :new-path (fn [path] (set acc.new-path path))}]
    (diff-parse.parse text handlers)
    (prepend-header acc ?old-ref ?new-ref)
    acc.rows))

(fn splittable? [rows]
  (var has-old false)
  (var has-new false)
  (each [_ row (ipairs (or rows [])) &until (and has-old has-new)]
    (when (= row.kind :change)
      (when row.old (set has-old true))
      (when row.new (set has-new true))))
  (and has-old has-new))

{: parse-rows : splittable?}
