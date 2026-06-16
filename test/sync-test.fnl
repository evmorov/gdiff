(local faith (require :faith))
(local sync (require :sync))
(local sys (require :sys))
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
  (faith.= ["main" "feature"]
           (sync.targets-for-revision "main..feature" "current"))
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
    (faith.match "printf 'branch" command)))

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
  (let [state (finish-with-output "# branch.head feature\n# branch.upstream origin/feature\n# branch.ab +0 -2\n")]
    (faith.= "Branch not in sync: feature vs origin/feature (+0/-2)"
             (sync.warning state))))

{: test-clean-branch-has-no-warning
 : test-combines-revision-side-warnings
 : test-keeps-old-current-branch-status-parser
 : test-range-revision-checks-both-sides
 : test-single-revision-checks-current-branch
 : test-target-status-command-is-quoted-and-structured
 : test-warns-when-branch-is-behind-upstream}
