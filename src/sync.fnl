(local sys (require :sys))

(local interval-seconds 600)

(fn branch-status-command [path]
  (let [tmp (.. path ".tmp")]
    (.. "( git fetch --quiet --prune 2>/dev/null; "
        "git status --porcelain=v2 --branch 2>/dev/null ) > "
        (sys.shell-quote tmp) " && mv " (sys.shell-quote tmp) " "
        (sys.shell-quote path))))

(fn spawn-branch-status [path]
  (sys.remove-file path)
  (sys.remove-file (.. path ".tmp"))
  (sys.background-command (branch-status-command path)))

(fn parse-branch-status [text]
  (var branch nil)
  (var upstream nil)
  (var ahead nil)
  (var behind nil)
  (each [line (string.gmatch (or text "") "[^\r\n]+")]
    (let [next-branch (line:match "^# branch%.head (.+)$")
          next-upstream (line:match "^# branch%.upstream (.+)$")
          (next-ahead next-behind) (line:match "^# branch%.ab %+([0-9]+) %-([0-9]+)$")]
      (when next-branch
        (set branch next-branch))
      (when next-upstream
        (set upstream next-upstream))
      (when next-ahead
        (set ahead (tonumber next-ahead))
        (set behind (tonumber next-behind)))))
  {:branch branch :upstream upstream :ahead (or ahead 0) :behind (or behind 0)})

(fn warning-for-status [status]
  (if (not status.branch)
      "Could not check branch sync"
      (= status.branch "(detached)")
      "Detached HEAD: branch sync unavailable"
      (not status.upstream)
      (.. "No upstream for " status.branch)
      (or (> status.ahead 0) (> status.behind 0))
      (.. "Branch not in sync: " status.branch " vs " status.upstream " (+"
          status.ahead "/-" status.behind ")")
      nil))

(fn warning-from-output [text]
  (warning-for-status (parse-branch-status text)))

(fn new-state []
  {:path (sys.temp-path) :running? false :warning nil :next_at 0})

(fn start [state]
  (when (not state.running?)
    (set state.running? true)
    (set state.next_at (+ (os.time) interval-seconds))
    (spawn-branch-status state.path)))

(fn finish [state output]
  (set state.warning (warning-from-output output))
  (set state.running? false)
  (sys.remove-file state.path))

(fn poll [state]
  (when state.running?
    (let [output (sys.read-file state.path)]
      (when output
        (finish state output)))))

(fn update [state]
  (poll state)
  (when (and (not state.running?) (>= (os.time) state.next_at))
    (start state)))

(fn warning [state]
  state.warning)

{: new-state : start : update : warning}
