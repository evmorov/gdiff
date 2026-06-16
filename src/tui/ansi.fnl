(local esc "\27")
(local nl "\r\n")

(local reset-style "\27[0m")

(fn color? []
  (not (os.getenv "NO_COLOR")))

(fn pattern-quote [s]
  (s:gsub "([^%w])" "%%%1"))

(fn reset-code []
  (if (color?) reset-style ""))

(fn apply-style [style text]
  (if (and (color?) style)
      (.. style text reset-style)
      text))

(fn restyle-after-resets [text style]
  (if (and (color?) style)
      (text:gsub (pattern-quote reset-style) (.. reset-style style))
      text))

(fn apply-block-style [style text]
  (if (and (color?) style)
      (.. style (restyle-after-resets text style) reset-style)
      text))

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

(fn match-ranges [plain query]
  (let [ranges []]
    (when (< 0 (length query))
      (var start 1)
      (var searching? true)
      (while searching?
        (let [(first last) (plain:find query start true)]
          (if first
              (do
                (table.insert ranges {:first first :last last})
                (set start (+ last 1)))
              (set searching? false)))))
    ranges))

(fn highlight-matches [s query start-code end-code]
  (let [s (tostring (or s ""))
        ranges (match-ranges (strip-ansi s) (or query ""))]
    (if (or (= (length ranges) 0) (not (color?)) (not start-code))
        s
        (let [end-code (or end-code reset-style)]
          (var out "")
          (var i 1)
          (var visible 1)
          (var range-index 1)
          (while (<= i (length s))
            (let [range (. ranges range-index)]
              (when (and range (= visible range.first))
                (set out (.. out start-code)))
              (if (ansi-sequence? s i)
                  (let [last (ansi-sequence-end s i)]
                    (set out (.. out (s:sub i last)))
                    (set i (+ last 1)))
                  (let [(ch next-i) (next-char s i)]
                    (set out (.. out ch))
                    (when (and range (= visible range.last))
                      (set out (.. out end-code))
                      (set range-index (+ range-index 1)))
                    (set visible (+ visible 1))
                    (set i next-i)))))
          out))))

(fn truncate [s width]
  (let [s (tostring (or s ""))]
    (if (<= (visible-length s) width)
        s
        (let [suffix (if (< 3 width) "..." "")
              limit (- width (length suffix))]
          (var i 1)
          (var visible 0)
          (var out "")
          (while (and (< visible limit) (<= i (length s)))
            (if (ansi-sequence? s i)
                (let [last (ansi-sequence-end s i)]
                  (set out (.. out (s:sub i last)))
                  (set i (+ last 1)))
                (let [(ch next-i) (next-char s i)]
                  (set out (.. out ch))
                  (set visible (+ visible 1))
                  (set i next-i))))
          (.. out suffix (reset-code))))))

{: apply-block-style
 : apply-style
 : color?
 : esc
 : highlight-matches
 : nl
 : next-char
 : pad-right
 : reset-code
 : reset-style
 : strip-ansi
 : truncate
 : visible-length}
