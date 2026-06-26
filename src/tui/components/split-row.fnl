(local ansi (require :tui.ansi))
(local pane (require :tui.components.pane))
(local symbols (require :tui.symbols))
(local surface (require :tui.surface))
(local theme (require :tui.theme))

(fn pane-measure [width scroll height]
  (let [scroll? (pane.scroll? scroll height)]
    {: scroll? :content-cols (pane.content-width width scroll height)}))

(fn gutter-width [?gutters]
  (if (and ?gutters (. ?gutters 1))
      (ansi.visible-length (. ?gutters 1))
      0))

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
          right-x-scroll
          ?right-highlight
          ?right-gutters]
  (let [left (pane-measure left-cols left-scroll body-rows)
        right (pane-measure right-cols right-scroll body-rows)
        right-selected? (if (= (type ?right-highlight) :table)
                            (. ?right-highlight row-index)
                            (= row-index ?right-highlight))
        gw (gutter-width ?right-gutters)
        gutter (if (> gw 0)
                   (or (and ?right-gutters (. ?right-gutters row-index))
                       (string.rep " " gw))
                   "")
        text-cols (math.max 0 (- right.content-cols gw))]
    (.. (pane.row-text ctx left-row left.content-cols left-x-scroll)
        (if left.scroll?
            (pane.scroll-marker ctx left-scroll row-index body-rows)
            "") (theme.color ctx.theme :muted symbols.line.vertical)
        gutter (pane.line-text right-line text-cols right-x-scroll
                              right-selected? ctx)
        (if right.scroll?
            (pane.scroll-marker ctx right-scroll row-index body-rows)
            ""))))

(fn draw [screen-row ctx ...]
  (surface.write-at screen-row 1 (line ctx ...)))

{: draw : line : pane-measure}
