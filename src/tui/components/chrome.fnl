(local footer (require :tui.components.footer))
(local chrome-layout (require :tui.components.chrome_layout))
(local header (require :tui.components.header))
(local layout (require :tui.layout))
(local surface (require :tui.surface))
(local theme (require :tui.theme))

(local bottom-rule chrome-layout.bottom-rule)
(local legacy-footer chrome-layout.legacy-footer)
(local split-divider-col chrome-layout.split-divider-col)

(fn header-rule [header cols ?divider-col]
  (header.rule-line header cols ?divider-col))

(fn view-footer [view]
  (chrome-layout.footer-node view))

(fn footer-right-col [cols right]
  (footer.right-col cols right))

(fn footer-rule-cols [cols left right]
  (footer.rule-cols cols left right))

(fn horizontal-scrollbars [line body cols _body-rows]
  (chrome-layout.horizontal-scrollbars line body cols))

(fn draw-header [ctx view]
  (header.draw ctx view.header
               (split-divider-col (chrome-layout.body view) ctx.cols)))

(fn draw-bottom-rule [ctx view]
  (let [bottom-region (layout.region ctx :bottom-rule)
        line (chrome-layout.bottom-line view bottom-region.cols)]
    (surface.write-row bottom-region.row (theme.color ctx.theme :muted line)
                       false)))

(fn styled-footer-text [ctx footer-node text]
  (footer.styled-text ctx footer-node text))

(fn draw-footer [ctx view]
  (footer.draw ctx (view-footer view)))

{: bottom-rule
 : draw-bottom-rule
 : draw-footer
 : draw-header
 : footer-rule-cols
 : footer-right-col
 : header-rule
 : horizontal-scrollbars
 : legacy-footer
 : styled-footer-text}
