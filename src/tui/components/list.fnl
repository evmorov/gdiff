(local ansi (require :tui.ansi))
(local context (require :tui.context))
(local row-view (require :tui.components.row))
(local scrollbar (require :tui.components.scrollbar))

(fn rows [node]
  (or node.rows []))

(fn draw [ctx node ?width]
  (let [width (or ?width ctx.cols)
        scroll? (scrollbar.visible? node.scroll (context.body-rows ctx))
        content-width (if scroll? (- width 1) width)]
    (for [i 1 (context.body-rows ctx)]
      (let [row (. (rows node) i)]
        (when (and row (> content-width 0))
          (row-view.draw ctx (ansi.truncate row.text content-width)
                         row.selected? content-width))
        (when scroll?
          (scrollbar.draw ctx node.scroll i (+ i 2) width
                          (context.body-rows ctx)))
        (io.write ansi.nl)))))

{: draw : rows}
