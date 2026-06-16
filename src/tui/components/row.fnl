(local ansi (require :tui.ansi))
(local theme (require :tui.theme))

(fn render [ctx line selected? width]
  (if selected?
      (theme.selected-row ctx.theme line width)
      (ansi.pad-right line width)))

(fn draw [ctx line selected? width ?newline]
  (io.write (render ctx line selected? width))
  (when ?newline
    (io.write ansi.nl)))

{: draw : render}
