(local ansi (require :tui.ansi))
(local footer-layout (require :tui.components.footer_layout))
(local footer-text (require :tui.components.footer_text))
(local layout (require :tui.layout))
(local symbols (require :tui.symbols))
(local surface (require :tui.surface))
(local theme (require :tui.theme))

(local left-width footer-layout.left-width)
(local right-col footer-layout.right-col)
(local right-text footer-layout.right-text)
(local rule-cols footer-layout.rule-cols)
(local styled-text footer-text.styled)
(local text-style footer-text.text-style)

(fn draw-right [ctx right]
  (when right
    (let [footer-region (layout.region ctx :footer)
          right (right-text right footer-region.cols)
          col (right-col footer-region.cols right)]
      (surface.write-at footer-region.row col
                        (.. (theme.color ctx.theme :muted symbols.line.vertical)
                            " " right)))))

(fn draw [ctx footer]
  (let [footer-region (layout.region ctx :footer)]
    (surface.clear-row footer-region.row)
    (when footer
      (let [right footer.right
            width (left-width footer-region.cols right)
            left (when footer.text (ansi.truncate footer.text width))]
        (when left
          (surface.write-at footer-region.row footer-region.col
                            (styled-text ctx footer left)))
        (draw-right ctx right)))))

{: draw
 : left-width
 : right-col
 : right-text
 : rule-cols
 : styled-text
 : text-style}
