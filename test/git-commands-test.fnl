(local commands (require :git.commands))
(local faith (require :faith))

(fn test-revision-exists-command-quotes-commit-revision []
  (faith.= "git rev-parse --verify --quiet 'feature branch^{commit}' >/dev/null 2>&1"
           (commands.revision-exists-command "feature branch")))

(fn test-basic-git-adapter-commands-are-centralized []
  (faith.= "git config --get interactive.diffFilter 2>/dev/null"
           (commands.diff-filter-command))
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

(fn test-untracked-command-lists-others []
  (faith.= "git -c core.quotePath=false ls-files --others --exclude-standard 2>&1"
           (commands.untracked-command)))

(fn test-staged-paths-command-lists-cached-names []
  (faith.= "git diff --cached --name-only --find-renames --find-copies 2>&1"
           (commands.staged-paths-command)))

{: test-basic-git-adapter-commands-are-centralized
 : test-preview-command-quotes-revision-and-path
 : test-preview-command-requests-full-context
 : test-working-commands-diff-against-head
 : test-working-untracked-preview-uses-no-index
 : test-untracked-command-lists-others
 : test-staged-paths-command-lists-cached-names
 : test-revision-exists-command-quotes-commit-revision}
