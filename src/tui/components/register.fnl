(import-macros {: defrenderer} :tui.macros)

(local lines-view (require :tui.components.lines))
(local list-view (require :tui.components.list))
(local renderer (require :tui.renderer))
(local screen-view (require :tui.components.screen))
(local split-view (require :tui.components.split))

(defrenderer :screen screen-view)
(defrenderer :split split-view)
(defrenderer :list list-view)
(defrenderer :lines lines-view)

{:registry renderer.registered}
