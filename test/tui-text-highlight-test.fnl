(local faith (require :faith))
(local highlight (require :tui.text-highlight))
(local text (require :tui.text))

(fn test-match-ranges-finds-plain-substrings []
  (faith.= [{:first 1 :last 2} {:first 4 :last 5}]
           (highlight.match-ranges "ab ab" "ab")))

(fn test-highlight-wraps-visible-matches []
  (faith.= "a<b>c" (highlight.highlight "abc" "b" "<" ">")))

(fn test-highlight-preserves-ansi-sequences []
  (let [out (highlight.highlight "\27[32mabc\27[0m" "b" "<" ">")]
    (faith.= "a<b>c" (text.strip-ansi out))
    (faith.is (out:find "\27[32m" 1 true))))

(fn test-highlight-returns-original-when-query-missing []
  (faith.= "abc" (highlight.highlight "abc" "z" "<" ">")))

{: test-highlight-preserves-ansi-sequences
 : test-highlight-returns-original-when-query-missing
 : test-highlight-wraps-visible-matches
 : test-match-ranges-finds-plain-substrings}
