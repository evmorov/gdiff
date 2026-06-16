(local ansi (require :tui.ansi))
(local context (require :tui.context))
(local lines-view (require :tui.components.lines))
(local list-view (require :tui.components.list))
(local row-view (require :tui.components.row))
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
              left-cols
              right-cols
              divider-col]
  (terminal.cursor screen-row 1)
  (when left-row
    (row-view.draw ctx (ansi.truncate left-row.text left-cols)
                   left-row.selected? left-cols))
  (terminal.cursor screen-row divider-col)
  (io.write (theme.color ctx.theme :muted "|"))
  (terminal.cursor screen-row (+ divider-col 1))
  (when right-line
    (io.write (ansi.truncate right-line right-cols))))

(fn draw [ctx node]
  (let [(left-cols right-cols divider-col) (widths ctx.cols node.ratio)
        rows (list-view.rows node.left)
        preview (lines-view.rows node.right)]
    (for [i 1 (context.body-rows ctx)]
      (draw-row (+ i 2) ctx (. rows i) (. preview i) left-cols right-cols
                divider-col))))

{: draw : widths}
