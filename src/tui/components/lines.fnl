(local ansi (require :tui.ansi))
(local column (require :tui.components.scrolling-column))
(local surface (require :tui.surface))

(fn rows [node]
  (or node.lines []))

(fn render-cell [_ctx line content-width x-scroll]
  (surface.write (ansi.crop line x-scroll content-width)))

(fn draw [ctx node ?width]
  (column.draw ctx node (rows node) render-cell ?width))

{: draw : rows}
