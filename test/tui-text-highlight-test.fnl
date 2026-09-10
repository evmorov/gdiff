(local faith (require :faith))
(local highlight (require :tui.text-highlight))
(local text (require :tui.text))

(fn test-match-ranges-finds-plain-substrings []
  (faith.= [{:first 1 :last 2} {:first 4 :last 5}]
           (highlight.match-ranges "ab ab" "ab")))

(fn test-match-ranges-counts-visible-characters []
  (faith.= [{:first 3 :last 3}] (highlight.match-ranges "a│b" "b")))

(fn test-highlight-wraps-visible-matches []
  (faith.= "a<b>c" (highlight.highlight "abc" "b" "<" ">")))

(fn test-highlight-positions-after-multibyte-character []
  (faith.= "a│<b>c" (highlight.highlight "a│bc" "b" "<" ">")))

(fn test-highlight-preserves-ansi-sequences []
  (let [out (highlight.highlight "\27[32mabc\27[0m" "b" "<" ">")]
    (faith.= "a<b>c" (text.strip-ansi out))
    (faith.is (out:find "\27[32m" 1 true))))

(fn test-highlight-returns-original-when-query-missing []
  (faith.= "abc" (highlight.highlight "abc" "z" "<" ">")))

(fn test-apply-places-start-code-next-to-the-first-visible-character []
  (faith.= "\27[32m<a>bc\27[0m"
           (highlight.apply "\27[32mabc\27[0m" [{:first 1 :last 1}] "<" ">"))
  (faith.= "a\27[0m<b>c" (highlight.apply "a\27[0mbc" [{:first 2 :last 2}] "<"
                                          ">")))

(fn test-apply-restores-start-code-after-resets-inside-a-range []
  (faith.= "a<b\27[0m<c>d" (highlight.apply "ab\27[0mcd" [{:first 2 :last 3}]
                                            "<" ">"))
  (faith.= "a<b\27[m<c>d" (highlight.apply "ab\27[mcd" [{:first 2 :last 3}] "<"
                                           ">"))
  (faith.= "a<b\27[32mc>d" (highlight.apply "ab\27[32mcd" [{:first 2 :last 3}]
                                            "<" ">"))
  (faith.= "a<b>\27[0mcd" (highlight.apply "ab\27[0mcd" [{:first 2 :last 2}]
                                           "<" ">")))

{: test-apply-places-start-code-next-to-the-first-visible-character
 : test-apply-restores-start-code-after-resets-inside-a-range
 : test-highlight-preserves-ansi-sequences
 : test-highlight-positions-after-multibyte-character
 : test-highlight-returns-original-when-query-missing
 : test-highlight-wraps-visible-matches
 : test-match-ranges-counts-visible-characters
 : test-match-ranges-finds-plain-substrings}
