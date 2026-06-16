(local faith (require :faith))
(local sync (require :sync))
(local sys (require :sys))
(local t (require :test-helper))

(fn finish-with-output [output]
  (let [state (sync.new-state)]
    (set state.running? true)
    (set state.next_at (+ (os.time) 999))
    (faith.is (sys.write-file state.path output))
    (sync.update state)
    state))

(fn test-warns-when-branch-is-behind-upstream []
  (t.reset-workdir)
  (let [state (finish-with-output "# branch.head feature\n# branch.upstream origin/feature\n# branch.ab +0 -2\n")]
    (faith.= "Branch not in sync: feature vs origin/feature (+0/-2)"
             (sync.warning state))))

(fn test-clean-branch-has-no-warning []
  (let [state (finish-with-output "# branch.head feature\n# branch.upstream origin/feature\n# branch.ab +0 -0\n")]
    (faith.= nil (sync.warning state))))

{: test-clean-branch-has-no-warning
 : test-warns-when-branch-is-behind-upstream}
