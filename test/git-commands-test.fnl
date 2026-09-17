(local commands (require :git.commands))
(local faith (require :faith))

(fn test-revision-exists-command-quotes-commit-revision []
  (faith.= "git rev-parse --verify --quiet 'feature branch^{commit}' >/dev/null 2>&1"
           (commands.revision-exists-command "feature branch")))

(fn test-cat-file-batch-command-quotes-specs []
  (faith.= "printf '%s\\n' 'HEAD:a b.rb' 'main:c.rb' | git cat-file --batch 2>/dev/null"
           (commands.cat-file-batch-command ["HEAD:a b.rb" "main:c.rb"])))

(fn test-basic-git-adapter-commands-are-centralized []
  (faith.= "git branch --show-current 2>/dev/null"
           (commands.current-branch-command))
  (faith.= "git rev-parse --show-toplevel 2>/dev/null"
           (commands.repo-root-command)))

(fn test-preview-command-quotes-revision-and-path []
  (faith.= "git diff --no-ext-diff --color=never --find-renames --find-copies 'main...feature' -- 'src/a b.rb'"
           (commands.preview-command "main...feature" {:path "src/a b.rb"}
                                     "never")))

(fn test-preview-command-requests-full-context []
  (faith.= "git diff --no-ext-diff --color=never --find-renames --find-copies -U99999 'main...feature' -- 'src/a b.rb'"
           (commands.preview-command "main...feature" {:path "src/a b.rb"}
                                     "never" true)))

(fn test-preview-command-includes-both-paths-of-a-rename []
  (faith.= "git diff --no-ext-diff --color=never --find-renames --find-copies HEAD -- 'old/a b.rb' 'new/a b.rb'"
           (commands.preview-command commands.working-revision
                                     {:path "new/a b.rb"
                                      :old_path "old/a b.rb"
                                      :status "R"}
                                     "never")))

(fn test-move-preview-command-diffs-old-blob-against-new-blob-or-file []
  (faith.= "git diff --no-ext-diff --color=never 'main:lib/a b.rb' 'feature:lib/steps/a b.rb' 2>&1"
           (commands.move-preview-command "main" "feature"
                                          {:kind "D"
                                           :moved_to "lib/steps/a b.rb"
                                           :path "lib/a b.rb"}))
  (faith.= "git diff --no-ext-diff --color=never -U99999 'HEAD:lib/a.rb' -- 'lib/steps/a.rb' 2>&1"
           (commands.move-preview-command "HEAD" nil
                                          {:kind "A"
                                           :moved_from "lib/a.rb"
                                           :path "lib/steps/a.rb"
                                           :untracked? true}
                                          true)))

(fn test-side-path-follows-renames-and-detected-moves []
  (let [renamed {:kind "R" :old_path "old.rb" :path "new.rb"}
        from {:kind "D" :moved_to "lib/new.rb" :path "old.rb"}
        to {:kind "A" :moved_from "old.rb" :path "lib/new.rb"}
        plain {:kind "M" :path "same.rb"}]
    (faith.= "old.rb" (commands.side-path renamed :old))
    (faith.= "new.rb" (commands.side-path renamed :new))
    (faith.= "old.rb" (commands.side-path from :old))
    (faith.= "lib/new.rb" (commands.side-path from :new))
    (faith.= "old.rb" (commands.side-path to :old))
    (faith.= "lib/new.rb" (commands.side-path to :new))
    (faith.= "same.rb" (commands.side-path plain :old))
    (faith.= "same.rb" (commands.side-path plain :new))
    (faith.= true (commands.move-pair? from))
    (faith.= true (commands.move-pair? to))
    (faith.= false (commands.move-pair? plain))))

(fn test-working-commands-diff-against-head []
  (faith.= "git diff --name-status --find-renames --find-copies HEAD 2>&1"
           (commands.diff-command commands.working-revision))
  (faith.= "git diff --numstat --find-renames --find-copies HEAD 2>&1"
           (commands.diff-stats-command commands.working-revision))
  (faith.= "git diff --no-ext-diff --color=never --find-renames --find-copies HEAD -- 'src/a b.rb'"
           (commands.preview-command commands.working-revision
                                     {:path "src/a b.rb" :status "M"} "never")))

(fn test-working-untracked-preview-uses-no-index []
  (faith.= "git diff --no-ext-diff --color=never --find-renames --find-copies --no-index -- /dev/null 'new file.rb'"
           (commands.preview-command commands.working-revision
                                     {:path "new file.rb"
                                      :status "?"
                                      :untracked? true}
                                     "never"))
  (faith.= "git diff --no-ext-diff --color=never --find-renames --find-copies --no-index -- /dev/null 'new file.rb' 2>&1 || true"
           (commands.plain-preview-command commands.working-revision
                                           {:path "new file.rb"
                                            :status "?"
                                            :untracked? true})))

(fn test-file-comparison-commands-diff-with-no-index []
  (let [revision (commands.files-revision "a 1.txt" "b/new.txt")]
    (faith.= "git diff --name-status --no-index -- 'a 1.txt' 'b/new.txt' 2>&1 || true"
             (commands.diff-command revision))
    (faith.= "git diff --numstat --no-index -- 'a 1.txt' 'b/new.txt' 2>&1 || true"
             (commands.diff-stats-command revision))
    (faith.= "git diff --no-ext-diff --color=never --find-renames --find-copies --no-index -- 'a 1.txt' 'b/new.txt' 2>&1 || true"
             (commands.plain-preview-command revision
                                             {:path "b/new.txt" :status "M"}))))

(fn test-folder-comparison-previews-diff-one-file-per-entry []
  (let [revision (commands.files-revision "old dir" "new")]
    (faith.= "git diff --no-ext-diff --color=never --find-renames --find-copies --no-index -- 'old dir/sub/mod.txt' 'new/sub/mod.txt' 2>&1 || true"
             (commands.plain-preview-command revision
                                             {:path "sub/mod.txt"
                                              :status "M"
                                              :old_file "old dir/sub/mod.txt"
                                              :new_file "new/sub/mod.txt"}))
    (faith.= "git diff --no-ext-diff --color=never --find-renames --find-copies --no-index -- '/dev/null' 'new/added.txt' 2>&1 || true"
             (commands.plain-preview-command revision
                                             {:path "added.txt"
                                              :status "A"
                                              :new_file "new/added.txt"}))
    (faith.= "git diff --no-ext-diff --color=never --find-renames --find-copies --no-index -- 'old dir/removed.txt' '/dev/null' 2>&1 || true"
             (commands.plain-preview-command revision
                                             {:path "removed.txt"
                                              :status "D"
                                              :old_file "old dir/removed.txt"}))))

(fn test-file-comparison-revision-round-trips-paths []
  (let [revision (commands.files-revision "a 1.txt" "b/new.txt")
        (left right) (commands.files-paths revision)]
    (faith.is (commands.files? revision))
    (faith.is (not (commands.files? "main...feature")))
    (faith.= "a 1.txt" left)
    (faith.= "b/new.txt" right)))

(fn test-show-file-command-quotes-ref-and-path []
  (faith.= "git show 'main:src/a b.rb' 2>/dev/null"
           (commands.show-file-command "main" "src/a b.rb")))

(fn test-blame-command-quotes-ref-and-path []
  (faith.= "git blame --line-porcelain 'main branch' -- 'src/a b.rb' 2>/dev/null"
           (commands.blame-command "main branch" "src/a b.rb"))
  (faith.= "git blame --line-porcelain -- 'src/a b.rb' 2>/dev/null"
           (commands.blame-command nil "src/a b.rb")))

(fn test-blame-command-limits-to-line-ranges []
  (faith.= "git blame --line-porcelain -L 3,5 -L 9,9 'main' -- 'a.rb' 2>/dev/null"
           (commands.blame-command "main" "a.rb" [[3 5] [9 9]]))
  (faith.= "git blame --line-porcelain -- 'a.rb' 2>/dev/null"
           (commands.blame-command nil "a.rb" [])))

(fn test-pr-info-command-asks-gh-for-refs []
  (faith.= "gh pr view 'https://github.com/acme/widgets/pull/17080' --json baseRefName,headRefName,headRefOid --jq '[.baseRefName, .headRefName, .headRefOid] | join(\"\\n\")' 2>/dev/null"
           (commands.pr-info-command "https://github.com/acme/widgets/pull/17080")))

(fn test-pr-fetch-commands-quote-refs []
  (faith.= "git fetch origin 'pull/17080/head' 2>&1"
           (commands.fetch-pr-head-command "17080"))
  (faith.= "git fetch origin 'release branch' 2>&1"
           (commands.fetch-branch-command "release branch")))

(fn test-resolve-commit-command-quotes-commit-revision []
  (faith.= "git rev-parse --verify --quiet 'feature branch^{commit}' 2>/dev/null"
           (commands.resolve-commit-command "feature branch")))

(fn test-commit-url-command-asks-gh-for-commit-page []
  (faith.= "gh browse --no-browser 'abc123' 2>/dev/null"
           (commands.commit-url-command "abc123")))

(fn test-base-temp-path-sanitizes-ref-and-keeps-path []
  (faith.= "/tmp/gdiff/origin_main/src/a.rb"
           (commands.base-temp-path "/tmp" "origin/main" "src/a.rb"))
  (faith.= "/tmp/gdiff/HEAD/a.rb"
           (commands.base-temp-path "/tmp" "HEAD" "a.rb")))

(fn test-untracked-command-lists-others []
  (faith.= "git -c core.quotePath=false ls-files --others --exclude-standard 2>&1"
           (commands.untracked-command)))

(fn test-staged-paths-command-lists-cached-names []
  (faith.= "git diff --cached --name-only --find-renames --find-copies 2>&1"
           (commands.staged-paths-command)))

{: test-basic-git-adapter-commands-are-centralized
 : test-blame-command-quotes-ref-and-path
 : test-file-comparison-commands-diff-with-no-index
 : test-folder-comparison-previews-diff-one-file-per-entry
 : test-file-comparison-revision-round-trips-paths
 : test-blame-command-limits-to-line-ranges
 : test-commit-url-command-asks-gh-for-commit-page
 : test-base-temp-path-sanitizes-ref-and-keeps-path
 : test-show-file-command-quotes-ref-and-path
 : test-preview-command-quotes-revision-and-path
 : test-preview-command-requests-full-context
 : test-preview-command-includes-both-paths-of-a-rename
 : test-move-preview-command-diffs-old-blob-against-new-blob-or-file
 : test-side-path-follows-renames-and-detected-moves
 : test-working-commands-diff-against-head
 : test-working-untracked-preview-uses-no-index
 : test-pr-fetch-commands-quote-refs
 : test-pr-info-command-asks-gh-for-refs
 : test-resolve-commit-command-quotes-commit-revision
 : test-untracked-command-lists-others
 : test-staged-paths-command-lists-cached-names
 : test-cat-file-batch-command-quotes-specs
 : test-revision-exists-command-quotes-commit-revision}
