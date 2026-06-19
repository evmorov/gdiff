(local commands (require :app.commands))

(fn command-or-none [value]
  (if (= (type value) :function) value commands.none))

(fn run [state config update command]
  (let [queue []]
    (var head 1)

    (fn dispatch [msg]
      (when msg
        (table.insert queue msg)))

    (fn get-state []
      state)

    (when command
      ((command-or-none command) dispatch get-state))
    (while (<= head (length queue))
      (let [msg (. queue head)
            (_ next-command) (update state config msg)]
        (set head (+ head 1))
        (when next-command
          ((command-or-none next-command) dispatch get-state)))))
  state)

{: command-or-none : run}
