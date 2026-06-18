(local commands (require :git.commands))
(local faith (require :faith))

(fn test-revision_exists_command_quotes_commit_revision []
  (faith.= "git rev-parse --verify --quiet 'feature branch^{commit}' >/dev/null 2>&1"
           (commands.revision-exists-command "feature branch")))

(fn test-basic_git_adapter_commands_are_centralized []
  (faith.= "git config --get interactive.diffFilter 2>/dev/null"
           (commands.diff-filter-command))
  (faith.= "git branch --show-current 2>/dev/null"
           (commands.current-branch-command))
  (faith.= "git rev-parse --show-toplevel 2>/dev/null"
           (commands.repo-root-command)))

(fn test-preview_command_quotes_revision_and_path []
  (faith.= "git diff --no-ext-diff --color=never --find-renames --find-copies 'main...feature' -- 'src/a b.rb'"
           (commands.preview-command "main...feature" {:path "src/a b.rb"}
                                     "never")))

{: test-basic_git_adapter_commands_are_centralized
 : test-preview_command_quotes_revision_and_path
 : test-revision_exists_command_quotes_commit_revision}
