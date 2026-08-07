(local git (require :git.core))
(local commands (require :git.sync-commands))
(local status (require :git.sync-status))
(local sys (require :platform.core))

(local branch-status-command commands.branch-status-command)
(local fetch-command commands.fetch-command)
(local target-status-command commands.target-status-command)

(fn add-target [targets seen target]
  (when (and target (> (length target) 0) (not (. seen target)))
    (tset seen target true)
    (table.insert targets target)))

(fn targets-for-revision [revision ?current-branch]
  (if (git.files? revision)
      []
      (let [current-branch (or ?current-branch (git.current-branch))
            targets []
            seen {}]
        (fn add-side [side]
          (add-target targets seen (if (> (length side) 0) side current-branch)))

        (let [(left right) (revision:match "^(.-)%.%.%.(.*)$")]
          (if left
              (do
                (add-side left)
                (add-side right))
              (add-target targets seen current-branch)))
        targets)))

(fn spawn-branch-status [path targets]
  (sys.remove-file path)
  (sys.remove-file (.. path ".tmp"))
  (sys.background-command (branch-status-command path targets)))

(fn new-state [?revision]
  {:path (sys.temp-path)
   :running? false
   :notice nil
   :warning nil
   :targets (targets-for-revision (or ?revision "HEAD"))})

(fn start [state ?spawn]
  (when (and (not state.running?) (< 0 (length state.targets)))
    (let [spawn (or ?spawn spawn-branch-status)]
      (set state.running? true)
      (spawn state.path state.targets)
      true)))

(fn finish [state output]
  (set state.notice (status.notice-from-output output))
  (set state.warning (status.warning-from-output output))
  (set state.running? false)
  (sys.remove-file state.path))

(fn poll [state]
  (when state.running?
    (let [output (sys.read-file state.path)]
      (when output
        (finish state output)))))

(fn update [state]
  (poll state))

(fn warning [state]
  state.warning)

(fn notice [state]
  state.notice)

{: new-state
 : notice
 : start
 : branch-status-command
 : fetch-command
 : target-status-command
 : targets-for-revision
 : update
 : warning}
