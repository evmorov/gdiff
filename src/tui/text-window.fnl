(local txt (require :tui.text))

(fn truncate [s width ?reset]
  (let [s (tostring (or s ""))
        reset (or ?reset "")]
    (if (<= (txt.visible-length s) width)
        s
        (let [suffix (if (< 3 width) "..." "")
              limit (- width (length suffix))
              out []]
          (var i 1)
          (var visible 0)
          (while (and (< visible limit) (<= i (length s)))
            (let [(text next-i cell-width) (txt.next-cell s i)]
              (table.insert out text)
              (set visible (+ visible cell-width))
              (set i next-i)))
          (.. (table.concat out) suffix reset)))))

(fn slice [s offset width]
  (let [s (tostring (or s ""))
        offset (math.max 0 (or offset 0))
        width (math.max 0 (or width 0))
        limit (+ offset width)
        out []]
    (var i 1)
    (var visible 0)
    (while (and (< visible limit) (<= i (length s)))
      (let [(text next-i cell-width) (txt.next-cell s i)]
        (when (or (= cell-width 0) (>= visible offset))
          (table.insert out text))
        (set visible (+ visible cell-width))
        (set i next-i)))
    (table.concat out)))

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
