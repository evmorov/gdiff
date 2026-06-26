(local layout (require :tui.layout))
(local scrollbar (require :tui.components.scrollbar))
(local surface (require :tui.surface))

(fn draw [ctx node items render-cell ?width]
  (let [width (or ?width ctx.cols)
        body (layout.body ctx)
        scroll? (scrollbar.visible? node.scroll body.rows)
        content-width (if scroll? (- width 1) width)
        x-scroll (or node.x-scroll 0)]
    (for [i 1 body.rows]
      (let [item (. items i)]
        (surface.clear-row (layout.row body i))
        (when (and item (> content-width 0))
          (render-cell ctx item content-width x-scroll i))
        (when scroll?
          (scrollbar.draw ctx node.scroll i (layout.row body i) width body.rows))
        (surface.newline)))))

{: draw}
