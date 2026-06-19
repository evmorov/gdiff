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

{: test-basic-git-adapter-commands-are-centralized
 : test-preview-command-quotes-revision-and-path
 : test-revision-exists-command-quotes-commit-revision}
