(local draw (require :tui.draw))
(local terminal (require :tui.terminal))
(local theme (require :tui.theme))

(fn run [program]
  (let [stty-state (terminal.saved-stty)]
    (let [(_ background-rgb) (terminal.raw-terminal stty-state)]
      (set program.state.theme (theme.new background-rgb)))
    (let [(ok err) (pcall (fn []
                            (set program.state.stty-state stty-state)
                            (var running true)
                            (while running
                              (draw.draw program.view program.state)
                              (set running
                                   (program.update program.state
                                                   (terminal.read-key program.state))))))]
      (terminal.restore-terminal stty-state)
      (when (not ok)
        (error err)))))

(fn run-loop [state view handle-key]
  (run {:state state :view view :update handle-key}))

{: run : run-loop}
