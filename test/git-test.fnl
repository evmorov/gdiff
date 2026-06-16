(local faith (require :faith))
(local git (require :git.core))
(local t (require :test-helper))

(fn entries-by-path [entries]
  (collect [_ entry (ipairs entries)]
    (values entry.path {:kind entry.kind
                        :old_path entry.old_path
                        :reviewed entry.reviewed
                        :status entry.status})))

(fn setup-changed-repo []
  (t.init-repo)
  (t.mkdir "spec/tardis/api")
  (t.write-file "added-later.txt" "")
  (t.write-file "deleted.txt" "delete me\n")
  (t.write-file "modified.txt" "before\n")
  (t.write-file "spec/tardis/api_spec.rb" "describe 'api' do\nend\n")
  (t.commit-all "initial")
  (t.write-file "added.txt" "new\n")
  (t.sh "git add added.txt")
  (t.write-file "modified.txt" "after\n")
  (t.sh "rm added-later.txt")
  (t.sh "rm deleted.txt")
  (t.sh "git mv spec/tardis/api_spec.rb spec/tardis/api/v2_spec.rb"))

(fn test-diff-entries-reports-working-tree-changes []
  (setup-changed-repo)
  (let [(entries err) (git.diff-entries "HEAD")]
    (faith.= nil err)
    (faith.= {"added-later.txt" {:kind "D" :reviewed false :status "D"}
              "added.txt" {:kind "A" :reviewed false :status "A"}
              "deleted.txt" {:kind "D" :reviewed false :status "D"}
              "modified.txt" {:kind "M" :reviewed false :status "M"}
              "spec/tardis/api/v2_spec.rb" {:kind "R"
                                            :old_path "spec/tardis/api_spec.rb"
                                            :reviewed false
                                            :status "R"}}
             (entries-by-path entries))))

(fn test-default-revision-prefers-main []
  (t.init-repo)
  (t.write-file "README.md" "# main\n")
  (t.commit-all "initial")
  (t.sh "git branch -M main")
  (let [(revision err) (git.default-revision)]
    (faith.= nil err)
    (faith.= "main" revision)))

(fn test-default-revision-falls-back-to-master []
  (t.init-repo)
  (t.write-file "README.md" "# master\n")
  (t.commit-all "initial")
  (t.sh "git branch -M master")
  (let [(revision err) (git.default-revision)]
    (faith.= nil err)
    (faith.= "master" revision)))

(fn test-comparison-revision-expands-single-revision []
  (faith.= "main...feature" (git.comparison-revision "main" "feature")))

(fn test-comparison-revision-keeps-explicit-range []
  (faith.= "main...feature"
           (git.comparison-revision "main...feature" "current"))
  (faith.= "current...feature" (git.comparison-revision "...feature" "current"))
  (faith.= "main...current" (git.comparison-revision "main..." "current")))

(fn test-comparison-right-selects_pr_branch []
  (faith.= "feature" (git.comparison-right "main...feature" "current"))
  (faith.= "current" (git.comparison-right "main...HEAD" "current"))
  (faith.= "current" (git.comparison-right "main..." "current"))
  (faith.= "current" (git.comparison-right "main" "current")))

(fn test-linked-pr-url-command-quotes-branch []
  (let [command (git.linked-pr-url-command "feature branch")]
    (faith.match "gh pr view 'feature branch'" command)
    (faith.match "%-%-json url %-%-jq %.url" command)
    (faith.match "2>/dev/null" command)))

{: test-default-revision-falls-back-to-master
 : test-default-revision-prefers-main
 : test-comparison-right-selects_pr_branch
 : test-comparison-revision-expands-single-revision
 : test-comparison-revision-keeps-explicit-range
 : test-diff-entries-reports-working-tree-changes
 : test-linked-pr-url-command-quotes-branch}
