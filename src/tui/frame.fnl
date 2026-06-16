(local terminal (require :tui.terminal))

(fn size-changed? [state rows cols]
  (or (not (= state.draw_rows rows)) (not (= state.draw_cols cols))))

(fn remember-size [state rows cols]
  (set state.draw_rows rows)
  (set state.draw_cols cols))

(fn prepare [state rows cols]
  (when (size-changed? state rows cols)
    (terminal.clear-screen)
    (remember-size state rows cols)))

(fn with-frame [f]
  (terminal.begin-frame)
  (let [(ok err) (pcall f)]
    (terminal.end-frame)
    (when (not ok)
      (error err))))

{: prepare : remember-size : size-changed? : with-frame}
