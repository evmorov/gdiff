(local ansi (require :tui.ansi))
(local surface (require :tui.surface))
(local theme (require :tui.theme))

(fn render [ctx line selected? width ?inactive?]
  (if selected? (theme.selected-row ctx.theme line width)
      ?inactive? (theme.inactive-row ctx.theme line width)
      (ansi.pad-right line width)))

(fn draw [ctx line selected? width ?newline ?inactive?]
  (surface.write (render ctx line selected? width ?inactive?))
  (when ?newline
    (surface.newline)))

{: draw : render}
