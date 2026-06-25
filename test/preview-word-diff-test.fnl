(local faith (require :faith))
(local word-diff (require :preview.word-diff))

(fn slice [s span]
  (and span (s:sub span.from (- span.to 1))))

(fn test-spans-isolate-the-changed-word []
  (let [old "foo bar baz"
        new "foo qux baz"
        {:old o :new n} (word-diff.spans old new)]
    (faith.= "bar" (slice old o))
    (faith.= "qux" (slice new n))))

(fn test-spans-mark-only-the-added-tail []
  (let [old "alpha beta"
        new "alpha beta gamma"
        {:old o :new n} (word-diff.spans old new)]
    (faith.= nil o)
    (faith.= "gamma" (slice new n))))

(fn test-spans-mark-only-the-removed-head []
  (let [old "drop keep tail"
        new "keep tail"
        {:old o :new n} (word-diff.spans old new)]
    (faith.= "drop" (slice old o))
    (faith.= nil n)))

(fn test-spans-empty-when-lines-match []
  (let [{:old o :new n} (word-diff.spans "same" "same")]
    (faith.= nil o)
    (faith.= nil n)))

{: test-spans-isolate-the-changed-word
 : test-spans-mark-only-the-added-tail
 : test-spans-mark-only-the-removed-head
 : test-spans-empty-when-lines-match}
