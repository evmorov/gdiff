(local ansi (require :tui.ansi))
(local nodes (require :tui.nodes))
(local theme (require :tui.theme))

(fn draw-header [ctx view]
  (io.write ansi.esc "[2J" ansi.esc "[H")
  (io.write (ansi.truncate view.header ctx.cols) ansi.nl)
  (io.write (theme.color ctx.theme :muted (string.rep "-" ctx.cols)) ansi.nl))

(fn draw-notice [ctx notice]
  (when notice
    (io.write ansi.esc "[" ctx.rows ";1H")
    (io.write (theme.color ctx.theme :notice (ansi.truncate notice ctx.cols)))))

(fn draw-warning [ctx warning]
  (when warning
    (io.write ansi.esc "[" ctx.rows ";1H")
    (io.write (theme.color ctx.theme :warning (ansi.truncate warning ctx.cols)))))

(fn legacy-footer [view]
  (if view.prompt (nodes.footer :notice view.prompt)
      view.warning (nodes.footer :warning view.warning)
      (nodes.footer :notice view.notice)))

(fn draw-footer [ctx view]
  (let [footer-node (or view.footer (legacy-footer view))]
    (when footer-node
      (case footer-node.type
        :warning (draw-warning ctx footer-node.text)
        :notice (draw-notice ctx footer-node.text)
        :prompt (draw-notice ctx footer-node.text)
        _ nil))))

{: draw-footer : draw-header : legacy-footer}
