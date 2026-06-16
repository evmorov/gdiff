(local esc "\27")
(local nl "\r\n")
(local colors-helper (require :tui.colors))

(local colors {:reset "\27[0m"
               :bold "\27[1m"
               :dim "\27[2m"
               :reverse "\27[7m"
               :added "\27[32m"
               :modified "\27[33m"
               :deleted "\27[31m"
               :renamed "\27[36m"
               :copied "\27[35m"
               :notice "\27[90m"
               :search "\27[30;43m"
               :search-end "\27[39;49m"})

(var selected-row-style nil)

(fn color? []
  (not (os.getenv "NO_COLOR")))

(fn color [name text]
  (if (color?)
      (.. (. colors name) text colors.reset)
      text))

(fn set-background-rgb [rgb]
  (set selected-row-style (colors-helper.background-style rgb)))

(fn pattern-quote [s]
  (s:gsub "([^%w])" "%%%1"))

(fn reset-code []
  (if (color?) colors.reset ""))

(fn search-code []
  colors.search)

(fn search-end-code []
  colors.search-end)

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

(fn visible-length [s]
  (let [s (tostring (or s ""))]
    (var i 1)
    (var len 0)
    (while (<= i (length s))
      (if (ansi-sequence? s i)
          (set i (+ (ansi-sequence-end s i) 1))
          (do
            (set len (+ len 1))
            (set i (+ i 1)))))
    len))

(fn pad-right [s width]
  (let [missing (- width (visible-length s))]
    (if (< 0 missing)
        (.. s (string.rep " " missing))
        s)))

(fn selected-row [line width]
  (let [line (pad-right line width)]
    (if (and (color?) selected-row-style)
        (let [style selected-row-style
              reset colors.reset]
          (.. style (line:gsub (pattern-quote reset) (.. reset style)) reset))
        line)))

(fn strip-ansi [s]
  (let [s (tostring (or s ""))]
    (var i 1)
    (var out "")
    (while (<= i (length s))
      (if (ansi-sequence? s i)
          (set i (+ (ansi-sequence-end s i) 1))
          (do
            (set out (.. out (s:sub i i)))
            (set i (+ i 1)))))
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

(fn highlight-matches [s query]
  (let [s (tostring (or s ""))
        ranges (match-ranges (strip-ansi s) (or query ""))]
    (if (= (length ranges) 0)
        s
        (let [start-code (search-code)
              end-code (search-end-code)]
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
                  (do
                    (set out (.. out (s:sub i i)))
                    (when (and range (= visible range.last))
                      (set out (.. out end-code))
                      (set range-index (+ range-index 1)))
                    (set visible (+ visible 1))
                    (set i (+ i 1))))))
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
                (do
                  (set out (.. out (s:sub i i)))
                  (set visible (+ visible 1))
                  (set i (+ i 1)))))
          (.. out suffix (reset-code))))))

{: color
 : esc
 : highlight-matches
 : nl
 : selected-row
 : set-background-rgb
 : strip-ansi
 : truncate
 : visible-length}
