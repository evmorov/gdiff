(local preview (require :preview.core))
(local tui (require :tui.core))
(local str (require :util.string))

(local contains? str.contains?)

(fn text-cache [state]
  (or state.search_text_cache (let [cache (setmetatable {} {:__mode :k})]
                                (set state.search_text_cache cache)
                                cache)))

(fn plain-lines [lines]
  (icollect [_ line (ipairs lines)]
    (tui.strip-ansi line)))

(fn plain-rows [rows]
  (icollect [_ row (ipairs rows)]
    {:old (and row.old (tui.strip-ansi row.old))
     :new (and row.new (tui.strip-ansi row.new))}))

(fn plain-texts [state source strip]
  "Styled preview text stripped for matching, memoized per source table."
  (let [cache (text-cache state)]
    (or (. cache source) (let [texts (strip source)]
                           (tset cache source texts)
                           texts))))

(fn content-row? [row]
  (or (= row.kind :change) (= row.kind :context)))

(fn split-match [index row query]
  (let [old? (and row.old (contains? row.old query))
        new? (and row.new (contains? row.new query))]
    (if (and old? new?) {:line index}
        old? {:line index :side :old}
        new? {:line index :side :new})))

(fn split-matches [state rows query]
  (icollect [index plain (ipairs (plain-texts state rows plain-rows))]
    (when (content-row? (. rows index))
      (split-match index plain query))))

(fn numbered? [?numbers index]
  "Header, divider, and git meta lines carry no line number. Previews
without number data count every line."
  (or (not= (type ?numbers) :table) (not= false (. ?numbers index))))

(fn unified-matches [state lines ?numbers query]
  (icollect [index line (ipairs (plain-texts state lines plain-lines))]
    (when (and (numbered? ?numbers index) (contains? line query))
      {:line index})))

(fn collect-matches [state entry query]
  "Matching content lines of `entry`'s cached preview, as `{:line index}`
records where `index` counts cached lines or split rows. File headers and
hunk headers are skipped. Split matches carry the side that matched unless
both sides do."
  (if (= 0 (length query)) [] (case (preview.cached-preview state entry)
                                (:split rows) (split-matches state rows query)
                                (:unified lines ?numbers) (unified-matches state
                                                                           lines
                                                                           ?numbers
                                                                           query)
                                _ [])))

{: collect-matches : contains?}
