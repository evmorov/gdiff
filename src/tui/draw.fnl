(require :tui.components.register)

(local context (require :tui.context))
(local frame (require :tui.frame))
(local renderer (require :tui.renderer))
(local split (require :tui.components.split))
(local terminal (require :tui.terminal))

(fn current-size [state]
  (if state.term_rows
      (values state.term_rows state.term_cols)
      (let [(rows cols) (terminal.terminal-size)]
        (set state.term_rows rows)
        (set state.term_cols cols)
        (values rows cols))))

(fn draw [view-fn state]
  (let [(rows cols) (current-size state)
        ctx (context.new rows cols state.theme)
        view (view-fn state ctx.rows ctx.cols)]
    (frame.with-frame (fn []
                        (frame.prepare state rows cols)
                        (renderer.draw ctx view)))
    (io.flush)))

{: draw :split-widths split.widths}
