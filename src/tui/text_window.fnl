(local txt (require :tui.text))

(fn truncate [s width ?reset]
  (let [s (tostring (or s ""))
        reset (or ?reset "")]
    (if (<= (txt.visible-length s) width)
        s
        (let [suffix (if (< 3 width) "..." "")
              limit (- width (length suffix))]
          (var i 1)
          (var visible 0)
          (var out "")
          (while (and (< visible limit) (<= i (length s)))
            (if (txt.ansi-sequence? s i)
                (let [last (txt.ansi-sequence-end s i)]
                  (set out (.. out (s:sub i last)))
                  (set i (+ last 1)))
                (let [(ch next-i) (txt.next-char s i)]
                  (set out (.. out ch))
                  (set visible (+ visible 1))
                  (set i next-i))))
          (.. out suffix reset)))))

(fn slice [s offset width]
  (let [s (tostring (or s ""))
        offset (math.max 0 (or offset 0))
        width (math.max 0 (or width 0))
        limit (+ offset width)]
    (var i 1)
    (var visible 0)
    (var out "")
    (while (and (< visible limit) (<= i (length s)))
      (if (txt.ansi-sequence? s i)
          (let [last (txt.ansi-sequence-end s i)]
            (set out (.. out (s:sub i last)))
            (set i (+ last 1)))
          (let [(ch next-i) (txt.next-char s i)]
            (when (>= visible offset)
              (set out (.. out ch)))
            (set visible (+ visible 1))
            (set i next-i))))
    out))

(fn crop [s offset width ?reset]
  (let [offset (math.max 0 (or offset 0))
        width (math.max 0 (or width 0))
        reset (or ?reset "")]
    (if (or (= offset 0) (= width 0))
        (truncate s width reset)
        (truncate (.. (slice s offset width) reset) width reset))))

(fn window [s offset width ?reset]
  (.. (slice s offset width) (or ?reset "")))

{: crop : slice : truncate : window}
