(local faith (require :faith))
(local matcher (require :app.preview-search-match))
(local preview-key (require :preview.key))

(local entry {:status "M" :kind "M" :path "a.rb" :reviewed false})

(fn state [lines ?split-rows ?numbers]
  (let [key (preview-key.for-entry "HEAD" entry)]
    {:revision "HEAD"
     :highlight? false
     :split_mode? (not= nil ?split-rows)
     :preview_cache {key lines}
     :preview_numbers_cache {key ?numbers}
     :split_cache {(.. key "\0split") ?split-rows}}))

(fn test-unnumbered-header-and-meta-lines-are-skipped []
  (let [state (state ["apple.rb"
                      "────────"
                      "@@ apple @@"
                      " apple pie"
                      "+apple"] nil
                     [false false false 3 4])
        matches (matcher.collect-matches state entry "apple")]
    (faith.= [{:line 4} {:line 5}] matches)))

(fn test-split-header-and-hunk-rows-are-skipped []
  (let [state (state ["-apple"]
                     [{:kind :filename :old "apple.rb" :new "apple.rb"}
                      {:kind :rule :old "────" :new "────"}
                      {:kind :hunk :old "@@ apple @@"}
                      {:kind :change :old "apple" :new "pear"}
                      {:kind :context :old "apple" :new "apple"}])
        matches (matcher.collect-matches state entry "apple")]
    (faith.= [{:line 4 :side :old} {:line 5}] matches)))

(fn test-collects-matching-cached-line-indices []
  (let [state (state ["alpha" "beta apple" "gamma" "apple pie"])
        matches (matcher.collect-matches state entry "apple")]
    (faith.= [{:line 2} {:line 4}] matches)))

(fn test-ignores-ansi-styling-when-matching []
  (let [state (state ["\27[32m+added apple\27[0m" " context"])
        matches (matcher.collect-matches state entry "apple")]
    (faith.= [{:line 1}] matches)))

(fn test-empty-query-yields-no-matches []
  (let [state (state ["apple"])]
    (faith.= [] (matcher.collect-matches state entry ""))))

(fn test-uncached-preview-yields-no-matches []
  (let [state (state ["apple"])]
    (faith.= [] (matcher.collect-matches state
                                         {:status "M" :kind "M" :path "b.rb"}
                                         "apple"))))

(fn test-split-rows-match-on-either-side []
  (let [state (state ["-old apple" "+new1"]
                     [{:kind :change :old "old apple" :new "new1"}
                      {:kind :change :old "old2" :new "new apple"}
                      {:kind :change :old "apple" :new "apple"}
                      {:kind :change :old "none" :new "none"}])
        matches (matcher.collect-matches state entry "apple")]
    (faith.= [{:line 1 :side :old} {:line 2 :side :new} {:line 3}] matches)))

(fn test-plain-text-is-memoized-per-source-table []
  (let [state (state ["\27[32mapple\27[0m"])
        key (preview-key.for-entry "HEAD" entry)
        lines (. state.preview_cache key)]
    (matcher.collect-matches state entry "apple")
    (faith.= ["apple"] (. state.search_text_cache lines))))

{: test-collects-matching-cached-line-indices
 : test-unnumbered-header-and-meta-lines-are-skipped
 : test-split-header-and-hunk-rows-are-skipped
 : test-ignores-ansi-styling-when-matching
 : test-empty-query-yields-no-matches
 : test-uncached-preview-yields-no-matches
 : test-split-rows-match-on-either-side
 : test-plain-text-is-memoized-per-source-table}
