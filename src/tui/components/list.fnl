(local ansi (require :tui.ansi))
(local column (require :tui.components.scrolling-column))
(local row-view (require :tui.components.row))

(fn rows [node]
  (or node.rows []))

(fn render-cell [ctx row content-width x-scroll]
  (row-view.draw ctx (ansi.crop row.text x-scroll content-width) row.selected?
                 content-width))

(fn draw [ctx node ?width]
  (column.draw ctx node (rows node) render-cell ?width))

{: draw : rows}
