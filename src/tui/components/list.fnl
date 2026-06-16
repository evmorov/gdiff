(local ansi (require :tui.ansi))
(local row-view (require :tui.components.row))

(fn rows [node]
  (or node.rows []))

(fn draw [ctx node ?width]
  (let [width (or ?width ctx.cols)]
    (each [_ row (ipairs (rows node))]
      (row-view.draw ctx (ansi.truncate row.text width) row.selected? width
                     true))))

{: draw : rows}
