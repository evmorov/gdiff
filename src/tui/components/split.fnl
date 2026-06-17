(local ansi (require :tui.ansi))
(local layout (require :tui.layout))
(local lines-view (require :tui.components.lines))
(local list-view (require :tui.components.list))
(local row-view (require :tui.components.row))
(local scrollbar (require :tui.components.scrollbar))
(local symbols (require :tui.symbols))
(local surface (require :tui.surface))
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

(fn horizontal-text [text width x-scroll _x-max-scroll]
  (ansi.pad-right (ansi.window text x-scroll width) width))

(fn left-text [ctx row width x-scroll x-max-scroll]
  (if (and row (> width 0))
      (row-view.render ctx
                       (horizontal-text row.text width x-scroll x-max-scroll)
                       row.selected? width)
      (spaces width)))

(fn right-text [line width x-scroll x-max-scroll]
  (if (and line (> width 0))
      (horizontal-text line width x-scroll x-max-scroll)
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
              right-cols
              left-x-scroll
              left-x-max-scroll
              right-x-scroll
              right-x-max-scroll]
  (let [left-scroll? (scrollbar.visible? left-scroll body-rows)
        left-content-cols (if left-scroll? (- left-cols 1) left-cols)
        right-scroll? (scrollbar.visible? right-scroll body-rows)
        right-content-cols (if right-scroll? (- right-cols 1) right-cols)
        line (.. (left-text ctx left-row left-content-cols left-x-scroll
                            left-x-max-scroll)
                 (if left-scroll?
                     (scroll-marker ctx left-scroll row-index body-rows)
                     "")
                 (theme.color ctx.theme :muted symbols.line.vertical)
                 (right-text right-line right-content-cols right-x-scroll
                             right-x-max-scroll)
                 (if right-scroll?
                     (scroll-marker ctx right-scroll row-index body-rows)
                     ""))]
    (surface.write-at screen-row 1 line)))

(fn draw [ctx node]
  (let [(left-cols right-cols) (widths ctx.cols node.ratio)
        body (layout.body ctx)
        rows (list-view.rows node.left)
        preview (lines-view.rows node.right)
        left-scroll node.left.scroll
        left-x-scroll (or node.left.x-scroll 0)
        left-x-max-scroll (or node.left.x-max-scroll 0)
        right-scroll node.right.scroll
        right-x-scroll (or node.right.x-scroll 0)
        right-x-max-scroll (or node.right.x-max-scroll 0)]
    (for [i 1 body.rows]
      (draw-row (layout.row body i) ctx (. rows i) (. preview i) left-scroll
                right-scroll i body.rows left-cols right-cols left-x-scroll
                left-x-max-scroll right-x-scroll right-x-max-scroll))))

{: draw : horizontal-text : widths}
