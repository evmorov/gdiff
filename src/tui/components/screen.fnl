(local chrome (require :tui.components.chrome))
(local nodes (require :tui.nodes))
(local renderer (require :tui.renderer))

(fn legacy-body [view]
  (if view.preview
      (nodes.split (nodes.list view.rows) (nodes.lines view.preview)
                   view.split_ratio)
      (nodes.list view.rows)))

(fn body-node [screen]
  (or screen.body (legacy-body screen)))

(fn draw [ctx screen]
  (chrome.draw-header ctx screen)
  (renderer.draw ctx (body-node screen))
  (chrome.draw-bottom-rule ctx screen)
  (chrome.draw-footer ctx screen)
  (when screen.overlay
    (renderer.draw ctx screen.overlay)))

{: body-node : draw : legacy-body}
