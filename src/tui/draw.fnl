(local body (require :tui.components.body))
(local chrome (require :tui.components.chrome))
(local context (require :tui.context))
(local split (require :tui.components.split))
(local terminal (require :tui.terminal))

(fn draw [view-fn state]
  (let [(rows cols) (terminal.terminal-size)
        ctx (context.new rows cols state.theme)
        view (view-fn state ctx.rows ctx.cols)]
    (chrome.draw-header ctx view)
    (body.draw ctx view)
    (chrome.draw-footer ctx view)
    (io.flush)))

{: draw :split-widths split.widths}
