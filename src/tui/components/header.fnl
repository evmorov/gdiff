(local ansi (require :tui.ansi))
(local footer-layout (require :tui.components.footer-layout))
(local layout (require :tui.layout))
(local rule (require :tui.components.rule))
(local surface (require :tui.surface))
(local symbols (require :tui.symbols))
(local theme (require :tui.theme))

(local left-width footer-layout.left-width)
(local right-col footer-layout.right-col)
(local right-text footer-layout.right-text)

(fn header-parts [header]
  (if (= (type header) :table)
      (values header.text header.right)
      header))

(fn divider-cols [?divider-col]
  (when ?divider-col
    {?divider-col true}))

(fn rule-line [header cols ?divider-col]
  (let [(left right) (header-parts header)]
    (rule.horizontal cols (footer-layout.rule-cols cols left right)
                     (divider-cols ?divider-col))))

(fn draw-right [ctx row cols right]
  (when right
    (let [right (right-text right cols)
          col (right-col cols right)]
      (surface.write-at row col (.. (theme.color ctx.theme :muted
                                                 symbols.line.vertical)
                                    " " right)))))

(fn draw [ctx header ?divider-col]
  (let [screen (layout.for-context ctx)
        header-region screen.header
        rule-region screen.header-rule
        (left right) (header-parts header)
        cols header-region.cols
        left (when left (ansi.truncate left (left-width cols right)))]
    (surface.clear-row header-region.row)
    (when left
      (surface.write-at header-region.row header-region.col left))
    (draw-right ctx header-region.row cols right)
    (surface.write-row rule-region.row
                       (theme.color ctx.theme :muted
                                    (rule-line header rule-region.cols
                                               ?divider-col))
                       true)))

{: draw : rule-line}
