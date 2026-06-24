(local faith (require :faith))
(local str (require :util.string))

(fn test-trim-strips-surrounding-whitespace []
  (faith.= "abc" (str.trim "  abc  "))
  (faith.= "a b" (str.trim "\t a b \n"))
  (faith.= "" (str.trim "   "))
  (faith.= "" (str.trim ""))
  (faith.= "" (str.trim nil)))

(fn test-contains-matches-plain-substring []
  (faith.is (str.contains? "hello world" "world"))
  (faith.is (not (str.contains? "hello" "xyz")))
  (faith.is (str.contains? "a.b.c" "."))
  (faith.is (str.contains? "anything" ""))
  (faith.is (not (str.contains? nil "x")))
  (faith.is (str.contains? nil "")))

{: test-trim-strips-surrounding-whitespace
 : test-contains-matches-plain-substring}
