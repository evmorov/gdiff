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
                            (var held nil)
                            (while running
                              (let [skip? (and program.state.skip_next_draw?
                                               (not program.state.force_next_draw?))]
                                (set program.state.skip_next_draw? false)
                                (set program.state.force_next_draw? false)
                                (when (not skip?)
                                  (draw.draw program.view program.state)))
                              (let [key (if held
                                            (let [k held]
                                              (set held nil)
                                              k)
                                            (terminal.read-key program.state))]
                                (set running (program.update program.state key))
                                (when (and running program.coalesce?
                                           (program.coalesce? program.state key))
                                  (let [(more-running held-key) (terminal.drain program.state
                                                                                #(program.coalesce? program.state
                                                                                                    $1)
                                                                                #(program.update program.state
                                                                                                 $1))]
                                    (set running more-running)
                                    (set held held-key)))))))]
      (terminal.restore-terminal stty-state)
      (when (not ok)
        (error err)))))

(fn run-loop [state view handle-key]
  (run {: state : view :update handle-key}))

{: run : run-loop}
