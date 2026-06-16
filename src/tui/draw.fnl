(require :tui.components.register)

(local context (require :tui.context))
(local frame (require :tui.frame))
(local renderer (require :tui.renderer))
(local split (require :tui.components.split))
(local terminal (require :tui.terminal))

(fn draw [view-fn state]
  (let [(rows cols) (terminal.terminal-size)
        ctx (context.new rows cols state.theme)
        view (view-fn state ctx.rows ctx.cols)]
    (frame.with-frame (fn []
                        (frame.prepare state rows cols)
                        (renderer.draw ctx view)))
    (io.flush)))

{: draw :split-widths split.widths}
