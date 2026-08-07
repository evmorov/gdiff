(local faith (require :faith))
(local blame (require :git.blame))
(local git (require :git.core))
(local sys (require :platform.core))
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

(fn test-comparison-revision-passes-file-comparison-through []
  (let [revision (git.files-revision "old.txt" "new.txt")]
    (faith.= revision (git.comparison-revision revision "current"))))

(fn test-comparison-sides-for-file-comparison-are-the-paths []
  (let [(old new) (git.comparison-sides (git.files-revision "old.txt" "new.txt"))]
    (faith.= "old.txt" old)
    (faith.= "new.txt" new)))

(fn setup-plain-files []
  (t.reset-workdir)
  (t.write-file "old.txt" "a\nb\n")
  (t.write-file "new.txt" "a\nc\n"))

(fn test-diff-entries-for-file-comparison-synthesizes-entry []
  (setup-plain-files)
  (let [(entries err) (git.diff-entries (git.files-revision "old.txt" "new.txt"))]
    (faith.= nil err)
    (faith.= [{:kind "M" :old_path "old.txt" :reviewed false :status "M"}]
             [(. (entries-by-path entries) "new.txt")])))

(fn test-diff-entries-for-identical-files-are-empty []
  (t.reset-workdir)
  (t.write-file "old.txt" "same\n")
  (t.write-file "new.txt" "same\n")
  (let [(entries err) (git.diff-entries (git.files-revision "old.txt" "new.txt"))]
    (faith.= nil err)
    (faith.= [] entries)))

(fn test-diff-stats-for-file-comparison-index-by-new-path []
  (setup-plain-files)
  (let [(stats err) (git.diff-stats (git.files-revision "old.txt" "new.txt"))]
    (faith.= nil err)
    (faith.= 1 stats.additions)
    (faith.= 1 stats.deletions)
    (faith.= {:additions 1 :deletions 1} (. stats.files "new.txt"))))

(fn test-plain-diff-output-for-file-comparison-shows-changes []
  (setup-plain-files)
  (let [entry {:path "new.txt" :old_path "old.txt" :status "M"}
        (output ok) (git.plain-diff-output (git.files-revision "old.txt"
                                                               "new.txt")
                                           entry)]
    (faith.is ok)
    (faith.match "%-b" output)
    (faith.match "%+c" output)))

(fn test-diff-base-ref-uses-merge-base-for-three-dot-ranges []
  (t.init-repo)
  (t.write-file "a.txt" "base\n")
  (t.commit-all "base")
  (t.sh "git branch -M main")
  (t.sh "git checkout -b feature")
  (t.write-file "a.txt" "feature\n")
  (t.commit-all "feature change")
  (t.sh "git checkout main")
  (t.write-file "b.txt" "advance\n")
  (t.commit-all "advance main")
  (let [(fork-point _) (sys.read-command "git merge-base main feature")]
    (faith.= (sys.trim fork-point) (git.diff-base-ref "main...feature"))))

(fn test-diff-base-ref-keeps-plain-revisions []
  (faith.= "HEAD" (git.diff-base-ref git.working-revision))
  (faith.= "main" (git.diff-base-ref "main")))

(fn test-blame-parser-builds-compact-date-author-labels []
  (let [output (table.concat ["abc 1 1 1"
                              "author Evgenii Morozov"
                              "author-time 1619654400"
                              "\tfirst"
                              "def 2 2"
                              "author Ada"
                              "author-time 1622246400"
                              "\tsecond"] "\n")
        lines (blame.parse output)]
    (faith.= "29/04/2021 Evgenii" (. lines 1))
    (faith.= "29/05/2021 Ada" (. lines 2))))

(fn test-blame-parser-crops-long-first-names-to-eight-symbols []
  (let [output (table.concat ["abc 1 1 1"
                              "author Alexandra Constantinescu"
                              "author-time 1619654400"
                              "\tline"] "\n")
        lines (blame.parse output)]
    (faith.= "29/04/2021 Alexandr" (. lines 1))))

(fn test-blame-ranges-merges-sorted-contiguous-lines []
  (faith.= [[1 3] [5 6] [10 10]] (blame.ranges [2 1 3 6 5 10]))
  (faith.= [[4 4]] (blame.ranges [4 4 4]))
  (faith.= [] (blame.ranges []))
  (faith.= [] (blame.ranges nil)))

(fn test-blame-lines-for-working-revision-use-head-and-worktree []
  (let [commands []
        old-read-command sys.read-command
        output (table.concat ["abc 1 1 1"
                              "author Evgenii"
                              "author-time 1619654400"
                              "\tline"] "\n")
        entry {:path "app.rb"}]
    (set sys.read-command (fn [cmd]
                            (table.insert commands cmd)
                            (values output true)))
    (git.blame-lines git.working-revision entry :old)
    (git.blame-lines git.working-revision entry :new)
    (set sys.read-command old-read-command)
    (faith.= "git blame --line-porcelain 'HEAD' -- 'app.rb' 2>/dev/null"
             (. commands 1))
    (faith.= "git blame --line-porcelain -- 'app.rb' 2>/dev/null"
             (. commands 2))))

(fn test-blame-lines-restricts-git-blame-to-given-ranges []
  (let [commands []
        old-read-command sys.read-command
        entry {:path "app.rb"}]
    (set sys.read-command (fn [cmd]
                            (table.insert commands cmd)
                            (values "" true)))
    (git.blame-lines git.working-revision entry :new [[3 5] [10 10]])
    (set sys.read-command old-read-command)
    (faith.= "git blame --line-porcelain -L 3,5 -L 10,10 -- 'app.rb' 2>/dev/null"
             (. commands 1))))

(fn test-blame-commit-parser-extracts-the-sha []
  (let [output (table.concat ["abc123def456 4 4 1"
                              "author Ada"
                              "author-time 1619654400"
                              "\tline"] "\n")]
    (faith.= "abc123def456" (blame.commit output))
    (faith.= nil (blame.commit ""))))

(fn test-blame-detects-not-yet-committed-lines []
  (faith.is (blame.uncommitted? "0000000000000000000000000000000000000000"))
  (faith.is (not (blame.uncommitted? "abc123")))
  (faith.is (not (blame.uncommitted? nil))))

(fn test-blame-commit-resolves-the-commit-for-a-single-line []
  (let [commands []
        old-read-command sys.read-command
        output (table.concat ["def789 3 3 1"
                              "author Ada"
                              "author-time 1619654400"
                              "\tline"] "\n")]
    (set sys.read-command (fn [cmd]
                            (table.insert commands cmd)
                            (values output true)))
    (let [(sha err) (git.blame-commit git.working-revision {:path "app.rb"}
                                      :new 3)]
      (set sys.read-command old-read-command)
      (faith.= "def789" sha)
      (faith.= nil err)
      (faith.= "git blame --line-porcelain -L 3,3 -- 'app.rb' 2>/dev/null"
               (. commands 1)))))

(fn test-blame-commit-reports-not-yet-committed-lines []
  (let [old-read-command sys.read-command
        output (table.concat ["0000000000000000000000000000000000000000 3 3 1"
                              "author Not Committed Yet"
                              "\tline"] "\n")]
    (set sys.read-command (fn [_cmd] (values output true)))
    (let [(sha err) (git.blame-commit git.working-revision {:path "app.rb"}
                                      :new 3)]
      (set sys.read-command old-read-command)
      (faith.= nil sha)
      (faith.= "Line is not committed yet" err))))

(fn test-commit-url-builds-url-from-gh-browse []
  (let [commands []
        old-read-command sys.read-command]
    (set sys.read-command
         (fn [cmd]
           (table.insert commands cmd)
           (values "https://github.com/o/r/commit/abc\n" true)))
    (let [(url err) (git.commit-url "abc")]
      (set sys.read-command old-read-command)
      (faith.= "https://github.com/o/r/commit/abc" url)
      (faith.= nil err)
      (faith.= "gh browse --no-browser 'abc' 2>/dev/null" (. commands 1)))))

(fn test-materialize-base-writes-committed-version-to-temp []
  (t.init-repo)
  (t.write-file "modified.txt" "before\n")
  (t.commit-all "initial")
  (t.write-file "modified.txt" "after\n")
  (let [(temp err) (git.materialize-base "HEAD" "modified.txt")]
    (faith.= nil err)
    (faith.= "before\n" (sys.read-file temp))))

(fn test-materialize-base-reports-missing-paths []
  (t.init-repo)
  (t.write-file "tracked.txt" "kept\n")
  (t.commit-all "initial")
  (let [(temp err) (git.materialize-base "HEAD" "untracked.txt")]
    (faith.= nil temp)
    (faith.= "Not in HEAD" err)))

(fn test-diff-stats-reports-total-additions-and-deletions []
  (setup-changed-repo)
  (let [(stats err) (git.diff-stats "HEAD")]
    (faith.= nil err)
    (faith.= 2 stats.additions)
    (faith.= 2 stats.deletions)
    (faith.= {:additions 1 :deletions 0} (. stats.files "added.txt"))
    (faith.= {:additions 1 :deletions 1} (. stats.files "modified.txt"))))

(fn test-diff-stats-code-totals-exclude-markdown-and-comments []
  (setup-changed-repo)
  (t.write-file "notes.md" "line\n")
  (t.write-file "script.rb" "# comment\nputs 1\n")
  (t.sh "git add notes.md script.rb")
  (let [(stats err) (git.diff-stats "HEAD")]
    (faith.= nil err)
    (faith.= 5 stats.additions)
    (faith.= 2 stats.deletions)
    (faith.= 3 stats.code_additions)
    (faith.= 2 stats.code_deletions)))

(fn test-diff-stats-no-tests-totals-exclude-test-folders []
  (setup-changed-repo)
  (t.write-file "spec/tardis/new_spec.rb" "puts 1\n")
  (t.sh "git add spec/tardis/new_spec.rb")
  (let [(stats err) (git.diff-stats "HEAD")]
    (faith.= nil err)
    (faith.= 3 stats.code_additions)
    (faith.= 2 stats.code_deletions)
    (faith.= 2 stats.no_tests_additions)
    (faith.= 2 stats.no_tests_deletions)))

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

(fn test-parse-pr-info-reads-gh-output-lines []
  (faith.= {:base-branch "main" :head-branch "feature" :head-oid "abc123"}
           (git.parse-pr-info "main\nfeature\nabc123\n"))
  (faith.= nil (git.parse-pr-info "main\nfeature"))
  (faith.= nil (git.parse-pr-info "")))

(fn setup-pr-origin []
  (t.init-repo)
  (t.sh "git init -b trunk origin-repo")
  (t.sh "git -C origin-repo config user.email gdiff@example.test")
  (t.sh "git -C origin-repo config user.name gdiff")
  (t.write-file "origin-repo/a.txt" "base\n")
  (t.sh "git -C origin-repo add .")
  (t.sh "git -C origin-repo commit -m base")
  (t.sh "git -C origin-repo checkout -b feature")
  (t.write-file "origin-repo/a.txt" "changed\n")
  (t.sh "git -C origin-repo add .")
  (t.sh "git -C origin-repo commit -m change")
  (t.sh "git -C origin-repo update-ref refs/pull/7/head feature")
  (t.sh "git remote add origin origin-repo")
  (let [(output _ok) (sys.read-command "git -C origin-repo rev-parse feature")]
    (sys.trim output)))

(fn test-pr-revision-fetches-pull-head-for-deleted-branch []
  (let [head-oid (setup-pr-origin)
        info {:base-branch "trunk" :head-branch "feature" :head-oid head-oid}]
    (t.sh "git -C origin-repo checkout trunk")
    (t.sh "git -C origin-repo branch -D feature")
    (let [(revision err) (git.pr-revision-from-info {:number "7"} info)]
      (faith.= nil err)
      (faith.= (.. "origin/trunk..." head-oid) revision))))

(fn test-pr-revision-uses-origin-head-branch-when-it-matches []
  (let [head-oid (setup-pr-origin)
        info {:base-branch "trunk" :head-branch "feature" :head-oid head-oid}
        (revision err) (git.pr-revision-from-info {:number "7"} info)]
    (faith.= nil err)
    (faith.= "origin/trunk...origin/feature" revision)))

(fn test-pr-revision-ignores-local-branches []
  (let [head-oid (setup-pr-origin)
        info {:base-branch "trunk" :head-branch "feature" :head-oid head-oid}
        (_revision err) (git.pr-revision-from-info {:number "7"} info)]
    (faith.= nil err)
    (t.sh "git branch trunk origin/trunk")
    (t.sh (.. "git branch feature " head-oid))
    (let [(revision err) (git.pr-revision-from-info {:number "7"} info)]
      (faith.= nil err)
      (faith.= "origin/trunk...origin/feature" revision))))

(fn test-pr-revision-refreshes-stale-origin-base []
  (let [head-oid (setup-pr-origin)
        info {:base-branch "trunk" :head-branch "feature" :head-oid head-oid}
        (_revision err) (git.pr-revision-from-info {:number "7"} info)]
    (faith.= nil err)
    (t.sh "git -C origin-repo checkout trunk")
    (t.write-file "origin-repo/b.txt" "more\n")
    (t.sh "git -C origin-repo add .")
    (t.sh "git -C origin-repo commit -m advance")
    (let [(revision err) (git.pr-revision-from-info {:number "7"} info)
          (new-tip _) (sys.read-command "git -C origin-repo rev-parse trunk")
          (local-tip _) (sys.read-command "git rev-parse origin/trunk")]
      (faith.= nil err)
      (faith.= "origin/trunk...origin/feature" revision)
      (faith.= (sys.trim new-tip) (sys.trim local-tip)))))

{: test-blame-parser-builds-compact-date-author-labels
 : test-blame-parser-crops-long-first-names-to-eight-symbols
 : test-blame-ranges-merges-sorted-contiguous-lines
 : test-blame-lines-for-working-revision-use-head-and-worktree
 : test-blame-lines-restricts-git-blame-to-given-ranges
 : test-blame-commit-parser-extracts-the-sha
 : test-blame-detects-not-yet-committed-lines
 : test-blame-commit-resolves-the-commit-for-a-single-line
 : test-blame-commit-reports-not-yet-committed-lines
 : test-commit-url-builds-url-from-gh-browse
 : test-materialize-base-reports-missing-paths
 : test-materialize-base-writes-committed-version-to-temp
 : test-default-revision-falls-back-to-master
 : test-default-revision-prefers-main
 : test-diff-base-ref-keeps-plain-revisions
 : test-diff-base-ref-uses-merge-base-for-three-dot-ranges
 : test-comparison-right-selects-pr-branch
 : test-comparison-revision-expands-single-revision
 : test-comparison-revision-keeps-explicit-range
 : test-comparison-revision-passes-working-through
 : test-comparison-revision-passes-file-comparison-through
 : test-comparison-sides-for-file-comparison-are-the-paths
 : test-diff-entries-for-file-comparison-synthesizes-entry
 : test-diff-entries-for-identical-files-are-empty
 : test-diff-stats-for-file-comparison-index-by-new-path
 : test-plain-diff-output-for-file-comparison-shows-changes
 : test-diff-entries-reports-working-tree-changes
 : test-diff-entries-with-working-marks-unstaged-changes
 : test-diff-entries-with-working-shows-modified-unstaged-file
 : test-diff-entries-with-working-keeps-staged-status
 : test-diff-stats-indexes-renamed-files-by-new-path
 : test-diff-stats-code-totals-exclude-markdown-and-comments
 : test-diff-stats-no-tests-totals-exclude-test-folders
 : test-diff-stats-reports-total-additions-and-deletions
 : test-linked-pr-url-command-quotes-branch
 : test-parse-pr-info-reads-gh-output-lines
 : test-pr-revision-fetches-pull-head-for-deleted-branch
 : test-pr-revision-ignores-local-branches
 : test-pr-revision-refreshes-stale-origin-base
 : test-pr-revision-uses-origin-head-branch-when-it-matches}
