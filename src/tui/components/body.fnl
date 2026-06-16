(import-macros {: defrenderer} :tui.macros)

(local lines-view (require :tui.components.lines))
(local list-view (require :tui.components.list))
(local nodes (require :tui.nodes))
(local renderer (require :tui.renderer))
(local split-view (require :tui.components.split))

(defrenderer :split split-view)
(defrenderer :list list-view)
(defrenderer :lines lines-view)

(fn legacy-body [view]
  (if view.preview
      (nodes.split (nodes.list view.rows) (nodes.lines view.preview)
                   view.split_ratio)
      (nodes.list view.rows)))

(fn draw [ctx view]
  (let [body (or view.body (legacy-body view))]
    (renderer.draw ctx body)))

{: draw : legacy-body}
