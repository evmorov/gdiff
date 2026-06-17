(local ansi (require :tui.ansi))
(local scrollbar (require :tui.components.scrollbar))
(local symbols (require :tui.symbols))

(fn scroll [x-scroll x-max-scroll visible]
  (when (and (< 0 (or x-max-scroll 0)) (< 0 visible))
    {:offset (or x-scroll 0) :visible visible :total (+ visible x-max-scroll)}))

(fn thumb [line start-col width x-scroll x-max-scroll]
  (let [scroll (scroll x-scroll x-max-scroll width)]
    (if (scrollbar.visible? scroll width)
        (let [out []
              last-col (+ start-col width -1)]
          (var i 1)
          (var col 1)
          (while (<= i (length line))
            (let [(ch next-i) (ansi.next-char line i)
                  relative-col (+ (- col start-col) 1)
                  mark (and (>= col start-col) (<= col last-col)
                            (scrollbar.marker scroll width relative-col
                                              symbols.line.horizontal-scroll-thumb))]
              (table.insert out (or mark ch))
              (set i next-i)
              (set col (+ col 1))))
          (table.concat out ""))
        line)))

{: scroll : thumb}
