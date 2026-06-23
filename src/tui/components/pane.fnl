(local ansi (require :tui.ansi))
(local row-view (require :tui.components.row))
(local scrollbar (require :tui.components.scrollbar))
(local theme (require :tui.theme))

(fn blank [width]
  (string.rep " " (math.max 0 width)))

(fn scroll? [scroll height]
  (scrollbar.visible? scroll height))

(fn content-width [width scroll height]
  (if (scroll? scroll height) (- width 1) width))

(fn scroll-marker [ctx scroll row height]
  (let [mark (scrollbar.marker scroll height row)]
    (if mark
        (theme.color ctx.theme :muted mark)
        " ")))

(fn window-text [text width x-scroll]
  (ansi.pad-right (ansi.window text x-scroll width) width))

(fn line-text [line width x-scroll ?selected? ?ctx]
  (if (and line (> width 0))
      (row-view.render ?ctx (window-text line width x-scroll) ?selected? width)
      (blank width)))

(fn row-text [ctx row width x-scroll]
  (if (and row (> width 0))
      (row-view.render ctx (window-text row.text width x-scroll) row.selected?
                       width)
      (blank width)))

{: blank
 : content-width
 : line-text
 : row-text
 : scroll?
 : scroll-marker
 : window-text}
