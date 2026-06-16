(local nodes (require :tui.nodes))
(local renderer (require :tui.renderer))

(fn legacy-body [view]
  (if view.preview
      (nodes.split (nodes.list view.rows) (nodes.lines view.preview)
                   view.split_ratio)
      (nodes.list view.rows)))

(fn draw [ctx view]
  (let [body (or view.body (legacy-body view))]
    (renderer.draw ctx body)))

{: draw : legacy-body}
