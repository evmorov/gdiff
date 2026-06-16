(local ansi (require :tui.ansi))
(local layout (require :tui.layout))
(local rule (require :tui.components.rule))
(local surface (require :tui.surface))
(local theme (require :tui.theme))

(fn separator-cols [header]
  (rule.separator-cols header 1))

(fn divider-cols [?divider-col]
  (when ?divider-col
    {?divider-col true}))

(fn rule-line [header cols ?divider-col]
  (rule.horizontal cols (separator-cols header) (divider-cols ?divider-col)))

(fn draw [ctx header ?divider-col]
  (let [screen (layout.for-context ctx)
        header-region screen.header
        rule-region screen.header-rule
        header (ansi.truncate header header-region.cols)]
    (surface.write-row header-region.row header true)
    (surface.write-row rule-region.row
                       (theme.color ctx.theme :muted
                                    (rule-line header rule-region.cols
                                               ?divider-col))
                       true)))

{: draw : rule-line : separator-cols}
