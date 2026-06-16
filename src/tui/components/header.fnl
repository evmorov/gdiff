(local ansi (require :tui.ansi))
(local rule (require :tui.components.rule))
(local terminal (require :tui.terminal))
(local theme (require :tui.theme))

(fn separator-cols [header]
  (rule.separator-cols header 1))

(fn divider-cols [?divider-col]
  (when ?divider-col
    {?divider-col true}))

(fn rule-line [header cols ?divider-col]
  (rule.horizontal cols (separator-cols header) (divider-cols ?divider-col)))

(fn draw [ctx header ?divider-col]
  (let [header (ansi.truncate header ctx.cols)]
    (terminal.cursor 1 1)
    (terminal.clear-line)
    (io.write header ansi.nl)
    (terminal.clear-line)
    (io.write (theme.color ctx.theme :muted
                           (rule-line header ctx.cols ?divider-col))
              ansi.nl)))

{: draw : rule-line : separator-cols}
