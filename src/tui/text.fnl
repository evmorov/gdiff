(local esc "\27")

(fn pattern-quote [s]
  (s:gsub "([^%w])" "%%%1"))

(fn ansi-sequence-end [s i]
  (var j (+ i 2))
  (var done? false)
  (while (and (not done?) (<= j (length s)))
    (let [byte (string.byte s j)]
      (if (and byte (<= 64 byte 126))
          (set done? true)
          (set j (+ j 1)))))
  (if done? j i))

(fn ansi-sequence? [s i]
  (and (= (s:sub i i) esc) (= (s:sub (+ i 1) (+ i 1)) "[")))

(fn utf8-char-end [s i]
  (let [byte (string.byte s i)
        last (length s)]
    (if (not byte) i
        (< byte 128) i
        (< byte 224) (math.min last (+ i 1))
        (< byte 240) (math.min last (+ i 2))
        (math.min last (+ i 3)))))

(fn next-char [s i]
  (let [byte (string.byte s i)]
    (if byte
        (let [last (utf8-char-end s i)]
          (values (s:sub i last) (+ last 1)))
        (values nil (+ i 1)))))

(fn visible-length [s]
  (let [s (tostring (or s ""))]
    (var i 1)
    (var len 0)
    (while (<= i (length s))
      (if (ansi-sequence? s i)
          (set i (+ (ansi-sequence-end s i) 1))
          (let [(_ next-i) (next-char s i)]
            (set len (+ len 1))
            (set i next-i))))
    len))

(fn pad-right [s width]
  (let [missing (- width (visible-length s))]
    (if (< 0 missing)
        (.. s (string.rep " " missing))
        s)))

(fn strip-ansi [s]
  (let [s (tostring (or s ""))]
    (var i 1)
    (var out "")
    (while (<= i (length s))
      (if (ansi-sequence? s i)
          (set i (+ (ansi-sequence-end s i) 1))
          (let [(ch next-i) (next-char s i)]
            (set out (.. out ch))
            (set i next-i))))
    out))

{: ansi-sequence-end
 : ansi-sequence?
 : esc
 : next-char
 : pad-right
 : pattern-quote
 : strip-ansi
 : utf8-char-end
 : visible-length}
