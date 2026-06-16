(local ansi (require :tui.ansi))
(local context (require :tui.context))
(local lines-view (require :tui.components.lines))
(local list-view (require :tui.components.list))
(local row-view (require :tui.components.row))
(local scrollbar (require :tui.components.scrollbar))
(local symbols (require :tui.symbols))
(local terminal (require :tui.terminal))
(local theme (require :tui.theme))

(fn widths [cols ?ratio]
  (let [ratio (or ?ratio 0.4)
        left-cols (math.max 1 (math.floor (* (- cols 1) ratio)))
        right-cols (math.max 1 (- cols left-cols 1))
        divider-col (+ left-cols 1)]
    (values left-cols right-cols divider-col)))

(fn spaces [n]
  (string.rep " " (math.max 0 n)))

(fn scroll-marker [ctx scroll row height]
  (let [mark (scrollbar.marker scroll height row)]
    (if mark
        (theme.color ctx.theme :muted mark)
        " ")))

(fn left-text [ctx row width]
  (if (and row (> width 0))
      (row-view.render ctx (ansi.truncate row.text width) row.selected? width)
      (spaces width)))

(fn right-text [line width]
  (if (and line (> width 0))
      (ansi.pad-right (ansi.truncate line width) width)
      (spaces width)))

(fn draw-row [screen-row
              ctx
              left-row
              right-line
              left-scroll
              right-scroll
              row-index
              body-rows
              left-cols
              right-cols]
  (terminal.cursor screen-row 1)
  (let [left-scroll? (scrollbar.visible? left-scroll body-rows)
        left-content-cols (if left-scroll? (- left-cols 1) left-cols)
        right-scroll? (scrollbar.visible? right-scroll body-rows)
        right-content-cols (if right-scroll? (- right-cols 1) right-cols)]
    (io.write (left-text ctx left-row left-content-cols))
    (when left-scroll?
      (io.write (scroll-marker ctx left-scroll row-index body-rows)))
    (io.write (theme.color ctx.theme :muted symbols.line.vertical))
    (io.write (right-text right-line right-content-cols))
    (when right-scroll?
      (io.write (scroll-marker ctx right-scroll row-index body-rows)))))

(fn draw [ctx node]
  (let [(left-cols right-cols) (widths ctx.cols node.ratio)
        rows (list-view.rows node.left)
        preview (lines-view.rows node.right)
        left-scroll node.left.scroll
        right-scroll node.right.scroll
        body-rows (context.body-rows ctx)]
    (for [i 1 body-rows]
      (draw-row (+ i 2) ctx (. rows i) (. preview i) left-scroll right-scroll i
                body-rows left-cols right-cols))))

{: draw : widths}
