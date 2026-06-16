(local faith (require :faith))
(local sync (require :git.sync))
(local sys (require :platform.core))
(local t (require :test-helper))

(fn finish-with-output [output ?revision]
  (let [state (sync.new-state ?revision)]
    (set state.running? true)
    (set state.next_at (+ (os.time) 999))
    (faith.is (sys.write-file state.path output))
    (sync.update state)
    state))

(fn test-single-revision-checks-current-branch []
  (faith.= ["feature"] (sync.targets-for-revision "main" "feature")))

(fn test-range-revision-checks-both-sides []
  (faith.= ["main" "feature"]
           (sync.targets-for-revision "main...feature" "current"))
  (faith.= ["current" "feature"]
           (sync.targets-for-revision "...feature" "current"))
  (faith.= ["main" "current"] (sync.targets-for-revision "main..." "current"))
  (faith.= ["feature"]
           (sync.targets-for-revision "feature...feature" "current")))

(fn test-target-status-command-is-quoted-and-structured []
  (let [command (sync.target-status-command "feature branch")]
    (faith.match "label='feature branch'" command)
    (faith.match "git branch %-%-show%-current" command)
    (faith.match "refs/heads/%$label" command)
    (faith.match "%$label@{upstream}" command)
    (faith.match "rev%-list %-%-left%-right %-%-count" command)
    (faith.match "printf '%%s\\t%%s\\t%%s\\t%%s\\t%%s\\n' branch" command)
    (faith.= nil (command:find "\n" 1 true))
    (faith.= nil (command:find "\t" 1 true))))

(fn test-fetch-command-is-quiet-and-noninteractive []
  (let [command (sync.fetch-command)]
    (faith.match "GIT_TERMINAL_PROMPT=0" command)
    (faith.match "GIT_ASKPASS=true" command)
    (faith.match "BatchMode=yes" command)
    (faith.match "git fetch %-%-quiet %-%-prune" command)
    (faith.match "</dev/null >/dev/null 2>&1" command)))

(fn test-branch-status-command-separates-target-subshells []
  (let [command (sync.branch-status-command "/tmp/gdiff-sync-status"
                                            ["main" "proxysql"])]
    (faith.match "%)%; %(" command)
    (faith.= nil (command:find ") (" 1 true))
    (faith.= nil (command:find "\n" 1 true))
    (faith.= nil (command:find "\t" 1 true))))

(fn test-background-branch-status-command-is-shell-parseable []
  (let [command (sync.branch-status-command "/tmp/gdiff-sync-status"
                                            ["main" "proxysql"])
        background (sys.background-shell-command command)
        (ok _kind _code) (os.execute (.. "sh -n -c "
                                         (sys.shell-quote background)))]
    (faith.is ok)))

(fn test-warns-when-branch-is-behind-upstream []
  (t.reset-workdir)
  (let [state (finish-with-output "branch\tfeature\torigin/feature\t0\t2\n")]
    (faith.= "Branch not in sync: feature vs origin/feature (+0/-2)"
             (sync.warning state))))

(fn test-clean-branch-has-no-warning []
  (let [state (finish-with-output "branch\tfeature\torigin/feature\t0\t0\n")]
    (faith.= nil (sync.warning state))))

(fn test-combines-revision-side-warnings []
  (let [state (finish-with-output (.. "branch\tmain\torigin/main\t0\t1\n"
                                      "branch\tfeature\torigin/feature\t2\t0\n")
                                  "main...feature")]
    (faith.= (.. "Branch not in sync: main vs origin/main (+0/-1); "
                 "Branch not in sync: feature vs origin/feature (+2/-0)")
             (sync.warning state))))

(fn test-keeps-old-current-branch-status-parser []
  (let [output (.. "# branch.head feature\n"
                   "# branch.upstream origin/feature\n" "# branch.ab +0 -2\n")
        state (finish-with-output output)]
    (faith.= "Branch not in sync: feature vs origin/feature (+0/-2)"
             (sync.warning state))))

{: test-clean-branch-has-no-warning
 : test-background-branch-status-command-is-shell-parseable
 : test-branch-status-command-separates-target-subshells
 : test-combines-revision-side-warnings
 : test-fetch-command-is-quiet-and-noninteractive
 : test-keeps-old-current-branch-status-parser
 : test-range-revision-checks-both-sides
 : test-single-revision-checks-current-branch
 : test-target-status-command-is-quoted-and-structured
 : test-warns-when-branch-is-behind-upstream}
