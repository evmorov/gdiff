(local faith (require :faith))
(local matcher (require :app.preview-search-match))

(fn state [display]
  {:preview_display_cache {: display}})

(fn test-collects-matching-display-line-indices []
  (let [state (state ["alpha" "beta apple" "gamma" "apple pie"])
        matches (matcher.collect-matches state "apple")]
    (faith.= 2 (length matches))
    (faith.= 2 (. matches 1 :line))
    (faith.= 4 (. matches 2 :line))))

(fn test-ignores-ansi-styling-when-matching []
  (let [state (state ["\27[32m+added apple\27[0m" " context"])
        matches (matcher.collect-matches state "apple")]
    (faith.= 1 (length matches))
    (faith.= 1 (. matches 1 :line))))

(fn test-empty-query-yields-no-matches []
  (let [state (state ["apple"])]
    (faith.= [] (matcher.collect-matches state ""))))

(fn test-missing-display-cache-yields-no-matches []
  (faith.= [] (matcher.collect-matches {} "apple")))

{: test-collects-matching-display-line-indices
 : test-ignores-ansi-styling-when-matching
 : test-empty-query-yields-no-matches
 : test-missing-display-cache-yields-no-matches}
