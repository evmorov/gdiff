(local chrome-layout (require :tui.components.chrome-layout))
(local footer (require :tui.components.footer))
(local header (require :tui.components.header))
(local layout (require :tui.layout))
(local surface (require :tui.surface))
(local theme (require :tui.theme))

(fn draw-header [ctx view]
  (header.draw ctx view.header
               (chrome-layout.split-divider-col (chrome-layout.body view)
                                                ctx.cols)))

(fn draw-bottom-rule [ctx view]
  (let [bottom-region (layout.region ctx :bottom-rule)
        line (chrome-layout.bottom-line view bottom-region.cols)]
    (surface.write-row bottom-region.row (theme.color ctx.theme :muted line)
                       false)))

(fn draw-footer [ctx view]
  (footer.draw ctx (chrome-layout.footer-node view)))

{: draw-bottom-rule : draw-footer : draw-header}
