(local faith (require :faith))
(local git (require :git.core))
(local t (require :test-helper))

(fn entries-by-path [entries]
  (collect [_ entry (ipairs entries)]
    (values entry.path {:kind entry.kind
                        :old_path entry.old_path
                        :reviewed entry.reviewed
                        :status entry.status})))

(fn staging-by-path [entries]
  (collect [_ entry (ipairs entries)]
    (values entry.path
            {:kind entry.kind
             :status entry.status
             :unstaged? (= true entry.unstaged?)
             :untracked? (= true entry.untracked?)})))

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
  (t.sh "git mv spec/tardis/api_spec.rb spec/tardis/api/v2_spec.rb")
  (t.write-file "untracked.txt" "fresh\n"))

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

(fn test-diff-entries-with-working-marks-unstaged-changes []
  (setup-changed-repo)
  (let [(entries err) (git.diff-entries git.working-revision)]
    (faith.= nil err)
    (faith.= {"added.txt" {:kind "A"
                           :status "A"
                           :unstaged? false
                           :untracked? false}
              "modified.txt" {:kind "M"
                              :status "M"
                              :unstaged? true
                              :untracked? false}
              "added-later.txt" {:kind "D"
                                 :status "D"
                                 :unstaged? true
                                 :untracked? false}
              "deleted.txt" {:kind "D"
                             :status "D"
                             :unstaged? true
                             :untracked? false}
              "untracked.txt" {:kind "A"
                               :status "A"
                               :unstaged? true
                               :untracked? true}
              "spec/tardis/api/v2_spec.rb" {:kind "R"
                                            :status "R"
                                            :unstaged? false
                                            :untracked? false}}
             (staging-by-path entries))))

(fn test-diff-entries-with-working-shows-modified-unstaged-file []
  (t.init-repo)
  (t.write-file "tardis.rb" "before\n")
  (t.commit-all "initial")
  (t.write-file "tardis.rb" "after\n")
  (let [(entries err) (git.diff-entries git.working-revision)]
    (faith.= nil err)
    (faith.= {"tardis.rb" {:kind "M"
                           :status "M"
                           :unstaged? true
                           :untracked? false}}
             (staging-by-path entries))))

(fn test-diff-entries-with-working-keeps-staged-status []
  (t.init-repo)
  (t.write-file "kept.txt" "base\n")
  (t.commit-all "initial")
  (t.write-file "kept.txt" "staged\n")
  (t.sh "git add kept.txt")
  (let [(entries err) (git.diff-entries git.working-revision)]
    (faith.= nil err)
    (faith.= {"kept.txt" {:kind "M"
                          :status "M"
                          :unstaged? false
                          :untracked? false}}
             (staging-by-path entries))))

(fn test-comparison-revision-passes-working-through []
  (faith.= git.working-revision
           (git.comparison-revision git.working-revision "current")))

(fn test-diff-stats-reports-total-additions-and-deletions []
  (setup-changed-repo)
  (let [(stats err) (git.diff-stats "HEAD")]
    (faith.= nil err)
    (faith.= 2 stats.additions)
    (faith.= 2 stats.deletions)
    (faith.= {:additions 1 :deletions 0} (. stats.files "added.txt"))
    (faith.= {:additions 1 :deletions 1} (. stats.files "modified.txt"))))

(fn test-diff-stats-indexes-renamed-files-by-new-path []
  (t.init-repo)
  (t.mkdir "spec/tardis")
  (t.write-file "spec/tardis/api_spec.rb" "old\n")
  (t.commit-all "initial")
  (t.sh "mkdir -p spec/tardis/api")
  (t.sh "git mv spec/tardis/api_spec.rb spec/tardis/api/v2_spec.rb")
  (t.write-file "spec/tardis/api/v2_spec.rb" "old\nnew\n")
  (let [(stats err) (git.diff-stats "HEAD")]
    (faith.= nil err)
    (faith.= {:additions 1 :deletions 0}
             (. stats.files "spec/tardis/api/v2_spec.rb"))))

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

(fn test-comparison-right-selects-pr-branch []
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
 : test-comparison-right-selects-pr-branch
 : test-comparison-revision-expands-single-revision
 : test-comparison-revision-keeps-explicit-range
 : test-comparison-revision-passes-working-through
 : test-diff-entries-reports-working-tree-changes
 : test-diff-entries-with-working-marks-unstaged-changes
 : test-diff-entries-with-working-shows-modified-unstaged-file
 : test-diff-entries-with-working-keeps-staged-status
 : test-diff-stats-indexes-renamed-files-by-new-path
 : test-diff-stats-reports-total-additions-and-deletions
 : test-linked-pr-url-command-quotes-branch}
