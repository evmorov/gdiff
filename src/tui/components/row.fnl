(local ansi (require :tui.ansi))
(local theme (require :tui.theme))

(fn draw [ctx line selected? width ?newline]
  (io.write (if selected? (theme.selected-row ctx.theme line width) line))
  (when ?newline
    (io.write ansi.nl)))

{: draw}
