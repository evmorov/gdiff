(local git (require :git.core))
(local background (require :git.background))
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

(fn sync-target? [target local-branch?]
  (or (= target "HEAD") (local-branch? target)))

(fn targets-for-revision [revision ?current-branch ?local-branch?]
  (if (git.files? revision)
      []
      (let [current-branch (or ?current-branch (git.current-branch))
            local-branch? (or ?local-branch? git.local-branch?)
            targets []
            seen {}]
        (fn add-side [side]
          (let [target (if (> (length side) 0) side current-branch)]
            (when (sync-target? target local-branch?)
              (add-target targets seen target))))

        (let [(left right) (revision:match "^(.-)%.%.%.(.*)$")]
          (if left
              (do
                (add-side left)
                (add-side right))
              (add-side "")))
        targets)))

(fn spawn-branch-status [path targets]
  (sys.remove-file path)
  (sys.remove-file (.. path ".tmp"))
  (sys.background-command (branch-status-command path targets)))

(fn new-state [?revision]
  (background.new-state {:notice nil
                         :warning nil
                         :targets (targets-for-revision (or ?revision "HEAD"))}))

(fn can-start? [state]
  (< 0 (length state.targets)))

(fn start [state ?spawn]
  (background.start state can-start? (or ?spawn spawn-branch-status)
                    state.targets))

(fn finish [state output]
  (set state.notice (status.notice-from-output output))
  (set state.warning (status.warning-from-output output)))

(fn update [state]
  (background.poll state finish))

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
