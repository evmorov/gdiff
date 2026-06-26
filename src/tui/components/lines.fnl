(local ansi (require :tui.ansi))
(local column (require :tui.components.scrolling-column))
(local surface (require :tui.surface))

(fn rows [node]
  (or node.lines []))

(fn gutter-width [gutters]
  (if (and gutters (. gutters 1))
      (ansi.visible-length (. gutters 1))
      0))

(fn draw [ctx node ?width]
  (let [gutters node.gutters
        width (gutter-width gutters)]
    (column.draw ctx node (rows node)
                 (fn [_ctx line content-width x-scroll i]
                   (let [?gutter (and gutters (. gutters i))]
                     (when ?gutter
                       (surface.write ?gutter))
                     (surface.write (ansi.crop line x-scroll
                                               (math.max 0
                                                         (- content-width width))))))
                 ?width)))

{: draw : rows}
