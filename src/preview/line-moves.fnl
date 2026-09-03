(local diff-parse (require :preview.diff-parse))
(local str (require :util.string))

(local min-key-length 4)
(local max-lines 20000)

(fn entry [line no group index]
  {: no :key (str.trim line) : group : index})

(fn collect-lines [text]
  (let [olds []
        news []
        acc {:old-no 1 :new-no 1 :group 0}]
    (diff-parse.parse text
                      {:hunk (fn [line]
                               (let [(old new) (diff-parse.hunk-start line)]
                                 (when old (set acc.old-no old))
                                 (when new (set acc.new-no new))))
                       :context (fn [_]
                                  (set acc.old-no (+ acc.old-no 1))
                                  (set acc.new-no (+ acc.new-no 1)))
                       :change (fn [removed added]
                                 (set acc.group (+ acc.group 1))
                                 (each [i line (ipairs removed)]
                                   (table.insert olds
                                                 (entry line
                                                        (+ acc.old-no i -1)
                                                        acc.group i)))
                                 (each [i line (ipairs added)]
                                   (table.insert news
                                                 (entry line
                                                        (+ acc.new-no i -1)
                                                        acc.group i)))
                                 (set acc.old-no
                                      (+ acc.old-no (length removed)))
                                 (set acc.new-no (+ acc.new-no (length added))))})
    (values olds news)))

(fn occurrences [entries]
  (let [out {}]
    (each [i e (ipairs entries)]
      (when (<= min-key-length (length e.key))
        (let [seen (or (. out e.key) [])]
          (table.insert seen i)
          (tset out e.key seen))))
    out))

(fn in-place? [o n]
  (and (= o.group n.group) (= o.index n.index)))

(fn matched-pairs [olds news]
  (let [old-at (occurrences olds)
        new-at (occurrences news)
        out []]
    (each [key olds-with (pairs old-at)]
      (let [news-with (. new-at key)]
        (when (and news-with (= (length olds-with) (length news-with)))
          (each [k i (ipairs olds-with)]
            (let [j (. news-with k)]
              (when (not (in-place? (. olds i) (. news j)))
                (table.insert out {:old i :new j})))))))
    (table.sort out #(< $1.old $2.old))
    out))

(fn extendable? [olds news used i j base]
  (let [o (. olds i)
        n (. news j)]
    (and o n (not (. used.old i)) (not (. used.new j))
         (= o.group base.old-group) (= n.group base.new-group) (= o.key n.key))))

(fn extend-block [olds news used pair]
  (let [base {:old-group (. olds pair.old :group)
              :new-group (. news pair.new :group)}]
    (var back 0)
    (while (extendable? olds news used (- pair.old back 1) (- pair.new back 1)
                        base)
      (set back (+ back 1)))
    (var forward 0)
    (while (extendable? olds news used (+ pair.old forward 1)
                        (+ pair.new forward 1) base)
      (set forward (+ forward 1)))
    {:old-from (- pair.old back)
     :new-from (- pair.new back)
     :length (+ back forward 1)}))

(fn range-of [entries from len]
  {:start (. entries from :no) :stop (. entries (+ from len -1) :no)})

(fn mark [range first?]
  (if first?
      {:start range.start :stop range.stop :first? true}
      {:start range.start :stop range.stop}))

(fn mark-block [marks used olds news block]
  (let [to (range-of news block.new-from block.length)
        from (range-of olds block.old-from block.length)]
    (for [k 0 (- block.length 1)]
      (let [i (+ block.old-from k)
            j (+ block.new-from k)]
        (tset used.old i true)
        (tset used.new j true)
        (tset marks.old (. olds i :no) (mark to (= k 0)))
        (tset marks.new (. news j :no) (mark from (= k 0)))))))

(fn detect [text]
  (let [(olds news) (collect-lines text)
        marks {:old {} :new {}}
        used {:old {} :new {}}]
    (when (<= (+ (length olds) (length news)) max-lines)
      (each [_ pair (ipairs (matched-pairs olds news))]
        (when (not (or (. used.old pair.old) (. used.new pair.new)))
          (mark-block marks used olds news (extend-block olds news used pair)))))
    marks))

(fn range-text [mark]
  (if (= mark.start mark.stop)
      (.. "line " mark.start)
      (.. "lines " mark.start "-" mark.stop)))

(fn annotation [side ?mark]
  (if (and ?mark ?mark.first?)
      (.. " (moved " (if (= side :old) "to " "from ") (range-text ?mark) ")")
      ""))

{: annotation : detect}
