(local ansi (require :tui.ansi))
(local context (require :tui.context))
(local lines-view (require :tui.components.lines))
(local list-view (require :tui.components.list))
(local row-view (require :tui.components.row))
(local scrollbar (require :tui.components.scrollbar))
(local terminal (require :tui.terminal))
(local theme (require :tui.theme))

(fn widths [cols ?ratio]
  (let [ratio (or ?ratio 0.4)
        left-cols (math.max 1 (math.floor (* (- cols 1) ratio)))
        right-cols (math.max 1 (- cols left-cols 1))
        divider-col (+ left-cols 1)]
    (values left-cols right-cols divider-col)))

(fn draw-row [screen-row
              ctx
              left-row
              right-line
              left-scroll
              right-scroll
              row-index
              body-rows
              left-cols
              right-cols
              divider-col]
  (terminal.cursor screen-row 1)
  (let [left-scroll? (scrollbar.visible? left-scroll body-rows)
        left-content-cols (if left-scroll? (- left-cols 1) left-cols)]
    (when (and left-row (> left-content-cols 0))
      (row-view.draw ctx (ansi.truncate left-row.text left-content-cols)
                     left-row.selected? left-content-cols))
    (when left-scroll?
      (scrollbar.draw ctx left-scroll row-index screen-row left-cols body-rows)))
  (terminal.cursor screen-row divider-col)
  (io.write (theme.color ctx.theme :muted "|"))
  (terminal.cursor screen-row (+ divider-col 1))
  (let [right-scroll? (scrollbar.visible? right-scroll body-rows)
        content-cols (if right-scroll? (- right-cols 1) right-cols)]
    (when (and right-line (> content-cols 0))
      (io.write (ansi.truncate right-line content-cols)))
    (when right-scroll?
      (scrollbar.draw ctx right-scroll row-index screen-row
                      (+ divider-col right-cols) body-rows))))

(fn draw [ctx node]
  (let [(left-cols right-cols divider-col) (widths ctx.cols node.ratio)
        rows (list-view.rows node.left)
        preview (lines-view.rows node.right)
        left-scroll node.left.scroll
        right-scroll node.right.scroll
        body-rows (context.body-rows ctx)]
    (for [i 1 body-rows]
      (draw-row (+ i 2) ctx (. rows i) (. preview i) left-scroll right-scroll i
                body-rows left-cols right-cols divider-col))))

{: draw : widths}
