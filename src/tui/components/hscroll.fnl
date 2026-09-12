(local ansi (require :tui.ansi))
(local scrollbar (require :tui.components.scrollbar))
(local symbols (require :tui.symbols))
(local scroll-util (require :util.scroll))

(fn scroll [x-scroll x-max-scroll visible]
  (when (< 0 visible)
    (scroll-util.info (or x-scroll 0) (+ visible (or x-max-scroll 0)) visible)))

(fn thumb [line start-col width x-scroll x-max-scroll]
  (let [scroll (scroll x-scroll x-max-scroll width)]
    (if (scrollbar.visible? scroll width)
        (let [out []
              last-col (+ start-col width -1)]
          (var i 1)
          (var col 1)
          (while (<= i (length line))
            (let [(text next-i cell-width) (ansi.next-cell line i)]
              (table.insert out (if (and (= cell-width 1) (>= col start-col)
                                         (<= col last-col))
                                    (or (scrollbar.marker scroll width
                                                          (+ (- col start-col)
                                                             1)
                                                          symbols.line.horizontal-scroll-thumb)
                                        text)
                                    text))
              (set i next-i)
              (set col (+ col cell-width))))
          (table.concat out ""))
        line)))

{: scroll : thumb}
