(local ansi (require :tui.ansi))
(local layout (require :tui.layout))
(local scrollbar (require :tui.components.scrollbar))
(local surface (require :tui.surface))

(fn rows [node]
  (or node.lines []))

(fn draw [ctx node ?width]
  (let [width (or ?width ctx.cols)
        body (layout.body ctx)
        scroll? (scrollbar.visible? node.scroll body.rows)
        content-width (if scroll? (- width 1) width)
        x-scroll (or node.x-scroll 0)]
    (for [i 1 body.rows]
      (let [line (. (rows node) i)]
        (surface.clear-row (layout.row body i))
        (when (and line (> content-width 0))
          (surface.write (ansi.crop line x-scroll content-width)))
        (when scroll?
          (scrollbar.draw ctx node.scroll i (layout.row body i) width body.rows))
        (surface.newline)))))

{: draw : rows}
