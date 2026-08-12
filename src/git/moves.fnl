;; Fuzzy pairing of deleted/added entries that git's own rename detection
;; left unpaired. Pure: `contents` maps entry tables to file contents.

(local max-pairs 400)
(local max-bytes (* 512 1024))
(local min-total 0.35)
(local runner-up-margin 0.1)
(local weights {:content 0.4 :identifiers 0.3 :name 0.2 :path 0.1})

(fn basename [path]
  (or (string.match (or path "") "([^/]+)$") path))

(fn extension [path]
  (or (string.match (basename path) "%.([^.]+)$") ""))

(fn candidates [entries]
  (let [deleted []
        added []]
    (each [_ entry (ipairs entries)]
      (case entry.kind
        "D" (table.insert deleted entry)
        "A" (table.insert added entry)))
    (when (and (< 0 (length deleted)) (< 0 (length added))
               (<= (* (length deleted) (length added)) max-pairs))
      {: deleted : added})))

(fn usable-content? [content]
  (and content (<= (length content) max-bytes)
       (not (string.find content "\0" 1 true))))

(fn line-set [content]
  (let [lines {}]
    (each [line (string.gmatch content "[^\n]+")]
      (let [trimmed (line:match "^%s*(.-)%s*$")]
        (when (< 3 (length trimmed))
          (tset lines trimmed true))))
    lines))

(fn identifier-set [lines]
  (let [ids {}]
    (each [line (pairs lines)]
      (each [id (string.gmatch line "[%a_][%w_]+")]
        (when (< 3 (length id))
          (tset ids id true))))
    ids))

(fn token-set [text pattern]
  (let [tokens {}]
    (each [token (string.gmatch text pattern)]
      (tset tokens token true))
    tokens))

(fn candidate-record [entry content]
  (let [lines (line-set content)]
    {: entry
     : lines
     :ids (identifier-set lines)
     :name-toks (token-set (basename entry.path) "%w+")
     :dirs (token-set entry.path "([^/]+)/")
     :base (basename entry.path)
     :ext (extension entry.path)}))

(fn line-weights [records]
  (let [freq {}]
    (each [_ record (ipairs records)]
      (each [line (pairs record.lines)]
        (tset freq line (+ 1 (or (. freq line) 0)))))
    (collect [line count (pairs freq)]
      (values line (/ 1 count)))))

(fn weighted-jaccard [a b ?weights]
  (fn weight [item]
    (or (and ?weights (. ?weights item)) 1))

  (var intersection 0)
  (var union 0)
  (each [item (pairs a)]
    (set union (+ union (weight item)))
    (when (. b item)
      (set intersection (+ intersection (weight item)))))
  (each [item (pairs b)]
    (when (not (. a item))
      (set union (+ union (weight item)))))
  (if (= union 0) 0 (/ intersection union)))

(fn pair-score [deleted added ?line-weights]
  (let [content (weighted-jaccard deleted.lines added.lines ?line-weights)
        ids (weighted-jaccard deleted.ids added.ids)
        name (if (= deleted.base added.base) 1
                 (weighted-jaccard deleted.name-toks added.name-toks))
        path (weighted-jaccard deleted.dirs added.dirs)]
    (+ (* weights.content content) (* weights.identifiers ids)
       (* weights.name name) (* weights.path path))))

(fn candidate-records [entries contents]
  (icollect [_ entry (ipairs entries)]
    (let [content (. contents entry)]
      (when (usable-content? content)
        (candidate-record entry content)))))

(fn scored-pairs [deleted added ?line-weights]
  (let [scored []]
    (each [_ d (ipairs deleted)]
      (each [_ a (ipairs added)]
        (when (= d.ext a.ext)
          (table.insert scored
                        {:from d :to a :score (pair-score d a ?line-weights)}))))
    scored))

(fn best-runner-up [scored]
  (let [best {}]
    (each [_ pair (ipairs scored)]
      (let [scores (or (. best pair.from) [0 0])]
        (tset best pair.from scores)
        (if (< (. scores 1) pair.score)
            (do
              (tset scores 2 (. scores 1))
              (tset scores 1 pair.score))
            (< (. scores 2) pair.score)
            (tset scores 2 pair.score))))
    best))

(fn acceptable? [pair runner-up]
  (and (<= min-total pair.score)
       (or (= pair.from.base pair.to.base)
           (<= runner-up-margin (- pair.score runner-up)))))

(fn assign-pairs [scored]
  (let [ranked (best-runner-up scored)
        used {}
        accepted []]
    (table.sort scored #(> $1.score $2.score))
    (each [_ pair (ipairs scored)]
      (when (and (not (. used pair.from)) (not (. used pair.to))
                 (acceptable? pair (. (. ranked pair.from) 2)))
        (tset used pair.from true)
        (tset used pair.to true)
        (table.insert accepted pair)))
    accepted))

(fn pair-moves [deleted added contents]
  (let [deleted-records (candidate-records deleted contents)
        added-records (candidate-records added contents)
        all []]
    (each [_ record (ipairs deleted-records)]
      (table.insert all record))
    (each [_ record (ipairs added-records)]
      (table.insert all record))
    (icollect [_ pair (ipairs (assign-pairs (scored-pairs deleted-records
                                                          added-records
                                                          (line-weights all))))]
      {:from pair.from.entry :to pair.to.entry :score pair.score})))

(fn note [entry]
  (let [percent (.. (math.floor (* 100 (or entry.moved_score 0))) "%")]
    (if entry.moved_to (.. " (moved to " entry.moved_to ", " percent ")")
        entry.moved_from (.. " (moved from " entry.moved_from ", " percent ")")
        "")))

(fn annotate [entries contents]
  (let [cands (candidates entries)]
    (when cands
      (each [_ pair (ipairs (pair-moves cands.deleted cands.added contents))]
        (set pair.from.moved_to pair.to.path)
        (set pair.from.moved_score pair.score)
        (set pair.to.moved_from pair.from.path)
        (set pair.to.moved_score pair.score))))
  entries)

{: annotate : basename : candidates : note : pair-moves}
