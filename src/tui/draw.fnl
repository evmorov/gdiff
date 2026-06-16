(local body (require :tui.components.body))
(local chrome (require :tui.components.chrome))
(local context (require :tui.context))
(local split (require :tui.components.split))
(local terminal (require :tui.terminal))

(fn size-changed? [state rows cols]
  (or (not (= state.draw_rows rows)) (not (= state.draw_cols cols))))

(fn remember-size [state rows cols]
  (set state.draw_rows rows)
  (set state.draw_cols cols))

(fn draw [view-fn state]
  (let [(rows cols) (terminal.terminal-size)
        ctx (context.new rows cols state.theme)
        view (view-fn state ctx.rows ctx.cols)]
    (terminal.begin-frame)
    (let [(ok err) (pcall (fn []
                            (when (size-changed? state rows cols)
                              (terminal.clear-screen)
                              (remember-size state rows cols))
                            (chrome.draw-header ctx view)
                            (body.draw ctx view)
                            (chrome.draw-bottom-rule ctx view)
                            (chrome.draw-footer ctx view)))]
      (terminal.end-frame)
      (when (not ok)
        (error err)))
    (io.flush)))

{: draw :split-widths split.widths}
