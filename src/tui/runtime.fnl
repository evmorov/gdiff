(local draw (require :tui.draw))
(local terminal (require :tui.terminal))
(local theme (require :tui.theme))

(local size-probe-ticks 10)

(fn read-key [program]
  ((or program.read-key terminal.read-key) program.state))

(fn draw-frame [program quick?]
  (let [state program.state
        skip? (and state.skip_next_draw? (not state.force_next_draw?))]
    (set state.skip_next_draw? false)
    (set state.force_next_draw? false)
    (when (not skip?)
      (set state.quick_frame? (and quick? true))
      ((or program.draw draw.draw) program.view state)
      (set state.quick_frame? false))))

(fn burst-key? [program key]
  (and program.coalesce? (program.coalesce? program.state key) true))

(fn run-burst [program]
  (var running true)
  (var held nil)
  (var done? false)
  (var quick-frames 0)
  (while (not done?)
    (let [key (read-key program)]
      (if (= key :tick) (set done? true) (burst-key? program key)
          (do
            (set running (program.update program.state key))
            (if running
                (do
                  (draw-frame program true)
                  (set quick-frames (+ quick-frames 1)))
                (set done? true)))
          (do
            (set held key)
            (set done? true)))))
  (set program.state.skip_next_draw? (= quick-frames 0))
  (set program.state.force_next_draw? (< 0 quick-frames))
  (values running held))

(fn probe-size-on-tick [program]
  (let [state program.state]
    (set state.tick_count (+ (or state.tick_count 0) 1))
    (when (>= state.tick_count size-probe-ticks)
      (set state.tick_count 0)
      (when (draw.refresh-size state)
        (set state.force_next_draw? true)))))

(fn loop [program]
  (var running true)
  (var held nil)
  (while running
    (draw-frame program false)
    (let [key (if held
                  (let [k held]
                    (set held nil)
                    k)
                  (read-key program))]
      (set running (program.update program.state key))
      (when (= key :tick)
        (probe-size-on-tick program))
      (when (and running (burst-key? program key))
        (draw-frame program false)
        (let [(more-running held-key) (run-burst program)]
          (set running more-running)
          (set held held-key))))))

(fn run [program]
  (let [stty-state (terminal.saved-stty)]
    (let [(_ background-rgb) (terminal.raw-terminal stty-state)]
      (set program.state.theme (theme.new background-rgb)))
    (let [(ok err) (pcall (fn []
                            (set program.state.stty_state stty-state)
                            (loop program)))]
      (terminal.restore-terminal stty-state)
      (when (not ok)
        (error err)))))

(fn run-loop [state view handle-key]
  (run {: state : view :update handle-key}))

{: draw-frame : loop : run : run-burst : run-loop}
