(local pane (require :tui.components.pane))
(local symbols (require :tui.symbols))
(local surface (require :tui.surface))
(local theme (require :tui.theme))

(fn line [ctx
          left-row
          right-line
          left-scroll
          right-scroll
          row-index
          body-rows
          left-cols
          right-cols
          left-x-scroll
          right-x-scroll]
  (let [left-scroll? (pane.scroll? left-scroll body-rows)
        left-content-cols (pane.content-width left-cols left-scroll body-rows)
        right-scroll? (pane.scroll? right-scroll body-rows)
        right-content-cols (pane.content-width right-cols right-scroll
                                               body-rows)]
    (.. (pane.row-text ctx left-row left-content-cols left-x-scroll)
        (if left-scroll?
            (pane.scroll-marker ctx left-scroll row-index body-rows)
            "") (theme.color ctx.theme :muted symbols.line.vertical)
        (pane.line-text right-line right-content-cols right-x-scroll)
        (if right-scroll?
            (pane.scroll-marker ctx right-scroll row-index body-rows)
            ""))))

(fn draw [screen-row ctx ...]
  (surface.write-at screen-row 1 (line ctx ...)))

{: draw : line}
