(local git (require :git))
(local sys (require :sys))

(local interval-seconds 300)

(fn add-target [targets seen target]
  (when (and target (> (length target) 0) (not (. seen target)))
    (tset seen target true)
    (table.insert targets target)))

(fn targets-for-revision [revision ?current-branch]
  (let [current-branch (or ?current-branch (git.current-branch))
        targets []
        seen {}]
    (fn add-side [side]
      (add-target targets seen (if (> (length side) 0) side current-branch)))

    (let [(triple-left triple-right) (revision:match "^(.-)%.%.%.(.*)$")
          (double-left double-right) (revision:match "^(.-)%.%.(.*)$")
          left (or triple-left double-left)
          right (or triple-right double-right)]
      (if left
          (do
            (add-side left)
            (add-side right))
          (add-target targets seen current-branch)))
    targets))

(fn target-status-command [target]
  (let [target (sys.shell-quote target)]
    (.. "( label=" target "; " "if [ \"$label\" = HEAD ]; then "
        "branch=$(git branch --show-current 2>/dev/null); "
        "if [ -z \"$branch\" ]; then printf 'detached\tHEAD\n'; exit 0; fi; "
        "label=\"$branch\"; " "fi; "
        "if ! git show-ref --verify --quiet \"refs/heads/$label\"; then "
        "printf 'skip\t%s\n' \"$label\"; exit 0; " "fi; "
        "upstream=$(git rev-parse --abbrev-ref \"$label@{upstream}\" 2>/dev/null); "
        "if [ -z \"$upstream\" ]; then printf 'no-upstream\t%s\n' \"$label\"; exit 0; fi; "
        "counts=$(git rev-list --left-right --count \"$upstream...$label\" 2>/dev/null); "
        "if [ -z \"$counts\" ]; then printf 'error\t%s\n' \"$label\"; exit 0; fi; "
        "set -- $counts; "
        "printf 'branch\t%s\t%s\t%s\t%s\n' \"$label\" \"$upstream\" \"$2\" \"$1\"; "
        ")")))

(fn branch-status-command [path targets]
  (let [tmp (.. path ".tmp")]
    (.. "( git fetch --quiet --prune 2>/dev/null; "
        (table.concat (icollect [_ target (ipairs targets)]
                        (target-status-command target))
                      " ") " ) > " (sys.shell-quote tmp) " && mv "
        (sys.shell-quote tmp) " " (sys.shell-quote path))))

(fn spawn-branch-status [path targets]
  (sys.remove-file path)
  (sys.remove-file (.. path ".tmp"))
  (sys.background-command (branch-status-command path targets)))

(fn parse-target-status-line [line]
  (let [(kind branch upstream ahead behind) (line:match "^([^\t]+)\t([^\t]*)\t?([^\t]*)\t?([^\t]*)\t?([^\t]*)$")]
    (case kind
      "branch" {:kind :branch
                :branch branch
                :upstream upstream
                :ahead (tonumber ahead)
                :behind (tonumber behind)}
      "detached" {:kind :detached :branch branch}
      "no-upstream" {:kind :no-upstream :branch branch}
      "error" {:kind :error :branch branch}
      "skip" {:kind :skip :branch branch}
      _ nil)))

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
  (if (= status.kind :skip)
      nil
      (= status.kind :detached)
      "Detached HEAD: branch sync unavailable"
      (= status.kind :no-upstream)
      (.. "No upstream for " status.branch)
      (= status.kind :error)
      (.. "Could not check branch sync for " status.branch)
      (not status.branch)
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
  (let [warnings []]
    (var target-output? false)
    (each [line (string.gmatch (or text "") "[^\r\n]+")]
      (let [status (parse-target-status-line line)]
        (when status
          (set target-output? true)
          (let [warning (warning-for-status status)]
            (when warning
              (table.insert warnings warning))))))
    (if (> (length warnings) 0) (table.concat warnings "; ")
        target-output? nil
        (warning-for-status (parse-branch-status text)))))

(fn new-state [?revision]
  {:path (sys.temp-path)
   :running? false
   :warning nil
   :next_at 0
   :targets (targets-for-revision (or ?revision "HEAD"))})

(fn start [state]
  (when (not state.running?)
    (set state.running? true)
    (set state.next_at (+ (os.time) interval-seconds))
    (spawn-branch-status state.path state.targets)))

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

{: new-state : start : targets-for-revision : update : warning}
