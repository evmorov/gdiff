(local commands (require :app.commands))

(fn command-or-none [value]
  (if (= (type value) :function) value commands.none))

(fn run [state config update command]
  (let [queue []]
    (fn dispatch [msg]
      (when msg
        (table.insert queue msg)))

    (fn get-state []
      state)

    (when command
      ((command-or-none command) dispatch get-state))
    (while (> (length queue) 0)
      (let [msg (table.remove queue 1)
            (_ next-command) (update state config msg)]
        (when next-command
          ((command-or-none next-command) dispatch get-state)))))
  state)

{: command-or-none : run}
