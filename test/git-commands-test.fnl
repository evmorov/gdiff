(local commands (require :git.commands))
(local faith (require :faith))

(fn test-revision-exists-command-quotes-commit-revision []
  (faith.= "git rev-parse --verify --quiet 'feature branch^{commit}' >/dev/null 2>&1"
           (commands.revision-exists-command "feature branch")))

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
  (faith.= "/tmp/gdiff-base/origin_main/src/a.rb"
           (commands.base-temp-path "/tmp" "origin/main" "src/a.rb"))
  (faith.= "/tmp/gdiff-base/HEAD/a.rb"
           (commands.base-temp-path "/tmp" "HEAD" "a.rb")))

(fn test-untracked-command-lists-others []
  (faith.= "git -c core.quotePath=false ls-files --others --exclude-standard 2>&1"
           (commands.untracked-command)))

(fn test-staged-paths-command-lists-cached-names []
  (faith.= "git diff --cached --name-only --find-renames --find-copies 2>&1"
           (commands.staged-paths-command)))

{: test-basic-git-adapter-commands-are-centralized
 : test-blame-command-quotes-ref-and-path
 : test-blame-command-limits-to-line-ranges
 : test-commit-url-command-asks-gh-for-commit-page
 : test-base-temp-path-sanitizes-ref-and-keeps-path
 : test-show-file-command-quotes-ref-and-path
 : test-preview-command-quotes-revision-and-path
 : test-preview-command-requests-full-context
 : test-working-commands-diff-against-head
 : test-working-untracked-preview-uses-no-index
 : test-pr-fetch-commands-quote-refs
 : test-pr-info-command-asks-gh-for-refs
 : test-resolve-commit-command-quotes-commit-revision
 : test-untracked-command-lists-others
 : test-staged-paths-command-lists-cached-names
 : test-revision-exists-command-quotes-commit-revision}
