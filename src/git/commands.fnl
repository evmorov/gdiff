(local sys (require :platform.core))

(local working-revision :working)

(fn working? [revision]
  (= revision working-revision))

(fn untracked? [entry]
  (= true entry.untracked?))

(fn diff-ref [revision]
  (if (working? revision) "HEAD" (sys.shell-quote revision)))

(fn untracked-command []
  "git -c core.quotePath=false ls-files --others --exclude-standard 2>&1")

(fn staged-paths-command []
  "git diff --cached --name-only --find-renames --find-copies 2>&1")

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
      (diff-ref revision) " 2>&1"))

(fn diff-stats-command [revision]
  (.. "git diff --numstat --find-renames --find-copies " (diff-ref revision)
      " 2>&1"))

(fn linked-pr-url-command [branch]
  (.. "gh pr view " (sys.shell-quote branch)
      " --json url --jq .url 2>/dev/null"))

(fn diff-target [revision entry]
  (if (and (working? revision) (untracked? entry))
      (.. "--no-index -- /dev/null " (sys.shell-quote entry.path))
      (.. (diff-ref revision) " -- " (sys.shell-quote entry.path))))

(local full-context-lines 99999)

(fn context-flag [?full-context?]
  (if ?full-context? (.. "-U" full-context-lines " ") ""))

(fn preview-command [revision entry color ?full-context?]
  (.. "git diff --no-ext-diff --color=" color " --find-renames --find-copies "
      (context-flag ?full-context?) (diff-target revision entry)))

(fn plain-preview-command [revision entry ?full-context?]
  (.. (preview-command revision entry "never" ?full-context?) " 2>&1"
      (if (and (working? revision) (untracked? entry)) " || true" "")))

(fn filtered-preview-command [revision entry filter ?full-context?]
  (.. (preview-command revision entry "always" ?full-context?)
      " 2>/dev/null | " filter " 2>/dev/null"))

{: current-branch-command
 : diff-command
 : diff-filter-command
 : diff-stats-command
 : filtered-preview-command
 : linked-pr-url-command
 : plain-preview-command
 : preview-command
 : repo-root-command
 : revision-exists-command
 : staged-paths-command
 : untracked-command
 : working-revision
 : working?}
