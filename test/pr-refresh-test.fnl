(local faith (require :faith))
(local pr-refresh (require :git.pr-refresh))
(local sys (require :platform.core))

(local pr {:owner "o"
           :repo "r"
           :number "7"
           :url "https://github.com/o/r/pull/7"})

(fn test-refresh-command-fetches-pr-info-and-refs []
  (let [command (pr-refresh.refresh-command "/tmp/gdiff-pr-refresh" pr)]
    (faith.match "gh pr view 'https://github%.com/o/r/pull/7'" command)
    (faith.match "git fetch origin \"%$head\"" command)
    (faith.match "'pull/7/head'" command)
    (faith.match "git fetch origin \"%$base\"" command)
    (faith.match "GIT_TERMINAL_PROMPT=0" command)
    (faith.= nil (command:find "\n" 1 true))
    (faith.= nil (command:find "\t" 1 true))))

(fn test-refresh-command-is-shell-parseable []
  (let [command (pr-refresh.refresh-command "/tmp/gdiff-pr-refresh" pr)
        background (sys.background-shell-command command)
        (ok _kind _code) (os.execute (.. "sh -n -c "
                                         (sys.shell-quote background)))]
    (faith.is ok)))

(fn test-start-requires-a-pr []
  (let [state (pr-refresh.new-state nil)]
    (faith.= nil (pr-refresh.start state #(faith.is false "should not spawn")))
    (faith.= false state.running?)))

(fn test-start-spawns-once-until-finished []
  (let [state (pr-refresh.new-state pr)
        calls []]
    (faith.= true
             (pr-refresh.start state
                               (fn [path spawned-pr]
                                 (table.insert calls {: path :pr spawned-pr}))))
    (faith.= true state.running?)
    (let [call (. calls 1)]
      (faith.= state.path call.path)
      (faith.= pr call.pr))
    (faith.= nil (pr-refresh.start state #(table.insert calls {})))
    (faith.= 1 (length calls))))

(fn test-update-reads-fetched-pr-info []
  (let [state (pr-refresh.new-state pr)]
    (set state.running? true)
    (faith.is (sys.write-file state.path "info\ttrunk\tfeature\tabc123\n"))
    (pr-refresh.update state)
    (faith.= false state.running?)
    (faith.= {:base-branch "trunk" :head-branch "feature" :head-oid "abc123"}
             state.info)
    (faith.= nil state.error)))

(fn test-update-reads-error []
  (let [state (pr-refresh.new-state pr)]
    (set state.running? true)
    (faith.is (sys.write-file state.path "error\tCould not read PR info\n"))
    (pr-refresh.update state)
    (faith.= false state.running?)
    (faith.= nil state.info)
    (faith.= "Could not read PR info" state.error)))

(fn test-parse-output-defaults-to-error []
  (faith.= {:error "Could not refresh PR"} (pr-refresh.parse-output ""))
  (faith.= {:error "Could not refresh PR"}
           (pr-refresh.parse-output "unexpected\n")))

{: test-parse-output-defaults-to-error
 : test-refresh-command-fetches-pr-info-and-refs
 : test-refresh-command-is-shell-parseable
 : test-start-requires-a-pr
 : test-start-spawns-once-until-finished
 : test-update-reads-error
 : test-update-reads-fetched-pr-info}
