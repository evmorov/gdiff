(local ansi (require :tui.ansi))
(local layout (require :tui.layout))
(local row-view (require :tui.components.row))
(local scrollbar (require :tui.components.scrollbar))
(local surface (require :tui.surface))

(fn rows [node]
  (or node.rows []))

(fn draw [ctx node ?width]
  (let [width (or ?width ctx.cols)
        body (layout.body ctx)
        scroll? (scrollbar.visible? node.scroll body.rows)
        content-width (if scroll? (- width 1) width)]
    (for [i 1 body.rows]
      (let [row (. (rows node) i)]
        (surface.clear-row (layout.row body i))
        (when (and row (> content-width 0))
          (row-view.draw ctx (ansi.truncate row.text content-width)
                         row.selected? content-width))
        (when scroll?
          (scrollbar.draw ctx node.scroll i (layout.row body i) width body.rows))
        (surface.newline)))))

{: draw : rows}
