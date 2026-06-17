(local pane (require :tui.components.pane))
(local symbols (require :tui.symbols))
(local surface (require :tui.surface))
(local theme (require :tui.theme))

(fn pane-measure [width scroll height]
  (let [scroll? (pane.scroll? scroll height)]
    {:scroll? scroll? :content-cols (pane.content-width width scroll height)}))

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
  (let [left (pane-measure left-cols left-scroll body-rows)
        right (pane-measure right-cols right-scroll body-rows)]
    (.. (pane.row-text ctx left-row left.content-cols left-x-scroll)
        (if left.scroll?
            (pane.scroll-marker ctx left-scroll row-index body-rows)
            "") (theme.color ctx.theme :muted symbols.line.vertical)
        (pane.line-text right-line right.content-cols right-x-scroll)
        (if right.scroll?
            (pane.scroll-marker ctx right-scroll row-index body-rows)
            ""))))

(fn draw [screen-row ctx ...]
  (surface.write-at screen-row 1 (line ctx ...)))

{: draw : line : pane-measure}
