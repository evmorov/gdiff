(local faith (require :faith))
(local highlight (require :tui.text_highlight))
(local text (require :tui.text))

(fn test-match_ranges_finds_plain_substrings []
  (faith.= [{:first 1 :last 2} {:first 4 :last 5}]
           (highlight.match-ranges "ab ab" "ab")))

(fn test-highlight_wraps_visible_matches []
  (faith.= "a<b>c" (highlight.highlight "abc" "b" "<" ">")))

(fn test-highlight_preserves_ansi_sequences []
  (let [out (highlight.highlight "\27[32mabc\27[0m" "b" "<" ">")]
    (faith.= "a<b>c" (text.strip-ansi out))
    (faith.is (out:find "\27[32m" 1 true))))

(fn test-highlight_returns_original_when_query_missing []
  (faith.= "abc" (highlight.highlight "abc" "z" "<" ">")))

{: test-highlight_preserves_ansi_sequences
 : test-highlight_returns_original_when_query_missing
 : test-highlight_wraps_visible_matches
 : test-match_ranges_finds_plain_substrings}
