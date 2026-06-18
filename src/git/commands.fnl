(local sys (require :platform.core))

(fn revision-exists-command [revision]
  (.. "git rev-parse --verify --quiet "
      (sys.shell-quote (.. revision "^{commit}")) " >/dev/null 2>&1"))

(fn diff-filter-command []
  "git config --get interactive.diffFilter 2>/dev/null")

(fn current-branch-command []
  "git branch --show-current 2>/dev/null")

(fn repo-root-command []
  "git rev-parse --show-toplevel 2>/dev/null")

(fn diff-command [revision]
  (.. "git diff --name-status --find-renames --find-copies "
      (sys.shell-quote revision) " 2>&1"))

(fn diff-stats-command [revision]
  (.. "git diff --numstat --find-renames --find-copies "
      (sys.shell-quote revision) " 2>&1"))

(fn linked-pr-url-command [branch]
  (.. "gh pr view " (sys.shell-quote branch)
      " --json url --jq .url 2>/dev/null"))

(fn preview-command [revision entry color]
  (.. "git diff --no-ext-diff --color=" color " --find-renames --find-copies "
      (sys.shell-quote revision) " -- " (sys.shell-quote entry.path)))

(fn plain-preview-command [revision entry]
  (.. (preview-command revision entry "never") " 2>&1"))

(fn filtered-preview-command [revision entry filter]
  (.. (preview-command revision entry "always") " 2>/dev/null | " filter
      " 2>/dev/null"))

{: current-branch-command
 : diff-command
 : diff-filter-command
 : diff-stats-command
 : filtered-preview-command
 : linked-pr-url-command
 : plain-preview-command
 : preview-command
 : repo-root-command
 : revision-exists-command}
