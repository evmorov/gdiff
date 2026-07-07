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

(fn test-crop-limits-to-character-count []
  (faith.= "Alexandr" (str.crop "Alexandra" 8))
  (faith.= "Jonathan" (str.crop "Jonathan" 8))
  (faith.= "Ada" (str.crop "Ada" 8))
  (faith.= "" (str.crop "" 8))
  (faith.= "" (str.crop nil 8))
  (faith.= "" (str.crop "abc" 0)))

(fn test-crop-does-not-split-multibyte-characters []
  (faith.= "Zoë" (str.crop "Zoë" 8))
  (faith.= "abcdefgé" (str.crop "abcdefgédef" 8))
  (faith.= "ëëëë" (str.crop "ëëëëëë" 4)))

{: test-trim-strips-surrounding-whitespace
 : test-contains-matches-plain-substring
 : test-crop-limits-to-character-count
 : test-crop-does-not-split-multibyte-characters}
