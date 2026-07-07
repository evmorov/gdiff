(fn trim [s]
  (let [s (or s "")]
    (or (s:match "^%s*(.-)%s*$") "")))

(fn contains? [text query]
  (let [text (or text "")]
    (not (= nil (text:find query 1 true)))))

(fn continuation-byte? [byte]
  (and byte (>= byte 128) (< byte 192)))

(fn crop [s max]
  "Return the first `max` UTF-8 characters of `s` without splitting a character."
  (let [s (or s "")
        len (length s)]
    (if (<= max 0)
        ""
        (do
          (var i 1)
          (var chars 0)
          (while (and (<= i len) (< chars max))
            (set i (+ i 1))
            (set chars (+ chars 1))
            (while (continuation-byte? (string.byte s i))
              (set i (+ i 1))))
          (s:sub 1 (- i 1))))))

{: contains? : crop : trim}
