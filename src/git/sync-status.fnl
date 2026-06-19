(local target-status-pattern
       "^([^\t]+)\t([^\t]*)\t?([^\t]*)\t?([^\t]*)\t?([^\t]*)$")

(fn parse-target-status-line [line]
  (let [(kind branch upstream ahead behind) (line:match target-status-pattern)]
    (case kind
      "branch" {:kind :branch
                : branch
                : upstream
                :ahead (tonumber ahead)
                :behind (tonumber behind)}
      "detached" {:kind :detached : branch}
      "fetch-error" {:kind :fetch-error :status branch}
      "no-upstream" {:kind :no-upstream : branch}
      "error" {:kind :error : branch}
      "skip" {:kind :skip : branch}
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
  {: branch : upstream :ahead (or ahead 0) :behind (or behind 0)})

(fn warning-for-status [status]
  (if (= status.kind :skip) nil
      (= status.kind :fetch-error) nil
      (= status.kind :detached) "Detached HEAD: branch sync unavailable"
      (= status.kind :no-upstream) nil
      (= status.kind :error) (.. "Could not check branch sync for "
                                 status.branch)
      (not status.branch) "Could not check branch sync"
      (= status.branch "(detached)") "Detached HEAD: branch sync unavailable"
      (not status.upstream) nil
      (< 0 status.behind) (.. "Branch not in sync: " status.branch " vs "
                              status.upstream " (+" status.ahead "/-"
                              status.behind ")")
      nil))

(fn notice-for-status [status]
  (if (= status.kind :fetch-error)
      "Could not sync remote"
      (= status.kind :no-upstream)
      (.. "No upstream for " status.branch)
      (and status.branch (not status.upstream))
      (.. "No upstream for " status.branch)
      nil))

(fn notice-from-output [text]
  (var notice nil)
  (each [line (string.gmatch (or text "") "[^\r\n]+")]
    (let [status (parse-target-status-line line)]
      (when (and status (not notice))
        (set notice (notice-for-status status)))))
  notice)

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
    (if (< 0 (length warnings)) (table.concat warnings "; ")
        target-output? nil
        (warning-for-status (parse-branch-status text)))))

{: notice-from-output
 : parse-branch-status
 : parse-target-status-line
 : warning-from-output}
