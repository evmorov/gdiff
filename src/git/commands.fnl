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

(fn current-branch-command []
  "git branch --show-current 2>/dev/null")

(fn repo-root-command []
  "git rev-parse --show-toplevel 2>/dev/null")

(fn show-file-command [ref path]
  (.. "git show " (sys.shell-quote (.. ref ":" path)) " 2>/dev/null"))

(fn range-flags [?ranges]
  (accumulate [flags "" _ r (ipairs (or ?ranges []))]
    (.. flags "-L " (tostring (. r 1)) "," (tostring (. r 2)) " ")))

(fn blame-command [?ref path ?ranges]
  (.. "git blame --line-porcelain " (range-flags ?ranges)
      (if ?ref (.. (sys.shell-quote ?ref) " ") "") "-- " (sys.shell-quote path)
      " 2>/dev/null"))

(fn base-temp-path [root ref path]
  (let [safe-ref (string.gsub ref "[/:]" "_")]
    (.. root "/gdiff-base/" safe-ref "/" path)))

(fn diff-command [revision]
  (.. "git diff --name-status --find-renames --find-copies "
      (diff-ref revision) " 2>&1"))

(fn diff-stats-command [revision]
  (.. "git diff --numstat --find-renames --find-copies " (diff-ref revision)
      " 2>&1"))

(fn linked-pr-url-command [branch]
  (.. "gh pr view " (sys.shell-quote branch)
      " --json url --jq .url 2>/dev/null"))

(fn commit-url-command [sha]
  (.. "gh browse --no-browser " (sys.shell-quote sha) " 2>/dev/null"))

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

{: base-temp-path
 : blame-command
 : commit-url-command
 : current-branch-command
 : diff-command
 : diff-stats-command
 : linked-pr-url-command
 : plain-preview-command
 : preview-command
 : repo-root-command
 : revision-exists-command
 : show-file-command
 : staged-paths-command
 : untracked-command
 : working-revision
 : working?}
