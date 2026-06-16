(local lines-view (require :tui.components.lines))
(local list-view (require :tui.components.list))
(local nodes (require :tui.nodes))
(local split-view (require :tui.components.split))

(fn legacy-body [view]
  (if view.preview
      (nodes.split (nodes.list view.rows) (nodes.lines view.preview)
                   view.split_ratio)
      (nodes.list view.rows)))

(fn draw [ctx view]
  (let [body (or view.body (legacy-body view))]
    (case body.type
      :split (split-view.draw ctx body)
      :list (list-view.draw ctx body)
      :lines (lines-view.draw ctx body)
      _ nil)))

{: draw : legacy-body}
