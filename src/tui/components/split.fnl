(local layout (require :tui.layout))
(local lines-view (require :tui.components.lines))
(local list-view (require :tui.components.list))
(local pane (require :tui.components.pane))
(local split-row (require :tui.components.split-row))

(fn widths [cols ?ratio]
  (let [ratio (or ?ratio 0.4)
        left-cols (math.max 1 (math.floor (* (- cols 1) ratio)))
        right-cols (math.max 1 (- cols left-cols 1))
        divider-col (+ left-cols 1)]
    (values left-cols right-cols divider-col)))

(fn horizontal-text [text width x-scroll _x-max-scroll]
  (pane.window-text text width x-scroll))

(fn draw [ctx node]
  (let [(left-cols right-cols) (widths ctx.cols node.ratio)
        body (layout.body ctx)
        rows (list-view.rows node.left)
        preview (lines-view.rows node.right)
        left-scroll node.left.scroll
        left-x-scroll (or node.left.x-scroll 0)
        right-scroll node.right.scroll
        right-x-scroll (or node.right.x-scroll 0)
        right-highlight node.right.highlight
        right-gutters node.right.gutters]
    (for [i 1 body.rows]
      (split-row.draw (layout.row body i) ctx (. rows i) (. preview i)
                      left-scroll right-scroll i body.rows left-cols right-cols
                      left-x-scroll right-x-scroll right-highlight right-gutters))))

{: draw : horizontal-text : widths}
