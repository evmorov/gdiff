(local sys (require :sys))

(fn split-tabs [line]
  (icollect [part (string.gmatch line "([^\t]+)")]
    part))

(fn entry [status path ?old-path]
  {:status status
   :kind (status:sub 1 1)
   :path path
   :old_path ?old-path
   :reviewed false})

(fn entry-from-name-status-line [line]
  (let [parts (split-tabs line)
        status (. parts 1)
        kind (and status (status:sub 1 1))]
    (case kind
      "A" (entry status (. parts 2))
      "M" (entry status (. parts 2))
      "D" (entry status (. parts 2))
      "R" (entry "R" (. parts 3) (. parts 2))
      "C" (entry "R" (. parts 3) (. parts 2))
      _ nil)))

(fn parse-name-status [text]
  (icollect [line (string.gmatch (or text "") "[^\r\n]+")]
    (entry-from-name-status-line line)))

(fn diff-command [revision]
  (.. "git diff --name-status --find-renames --find-copies "
      (sys.shell-quote revision) " 2>&1"))

(fn diff-filter []
  (let [(output ok _kind _code) (sys.read-command "git config --get interactive.diffFilter 2>/dev/null")
        filter (sys.trim output)]
    (if (and ok (> (length filter) 0))
        filter)))

(fn preview-context []
  {:diff-filter (diff-filter)})

(fn current-branch []
  (let [(output ok _kind _code) (sys.read-command "git branch --show-current 2>/dev/null")
        branch (sys.trim output)]
    (if (and ok (> (length branch) 0))
        branch
        "HEAD")))

(fn comparison-label [revision]
  (let [(left right) (revision:match "^(.-)%.%.%.(.*)$")]
    (if left
        (.. (if (> (length left) 0) left (current-branch)) "..."
            (if (> (length right) 0) right (current-branch)))
        (.. revision "..." (current-branch)))))

(fn preview-command [revision entry color]
  (.. "git diff --no-ext-diff --color=" color " --find-renames --find-copies "
      (sys.shell-quote revision) " -- " (sys.shell-quote entry.path)))

(fn plain-preview-command [revision entry]
  (.. (preview-command revision entry "never") " 2>&1"))

(fn filtered-preview-command [revision entry filter]
  (.. (preview-command revision entry "always") " 2>/dev/null | " filter
      " 2>/dev/null"))

(fn diff-entries [revision]
  (let [(output ok _kind _code) (sys.read-command (diff-command revision))]
    (if ok
        (values (parse-name-status output) nil)
        (values nil (sys.trim output)))))

(fn preview-output [context revision entry]
  (let [filter context.diff-filter]
    (if filter
        (let [(output ok _kind _code) (sys.read-command (filtered-preview-command revision
                                                                                  entry
                                                                                  filter))]
          (if ok
              (values output true true)
              (let [(output ok _kind _code) (sys.read-command (plain-preview-command revision
                                                                                     entry))]
                (values output ok false))))
        (let [(output ok _kind _code) (sys.read-command (plain-preview-command revision
                                                                               entry))]
          (values output ok false)))))

(fn repo-root []
  (let [(output ok _kind _code) (sys.read-command "git rev-parse --show-toplevel 2>/dev/null")]
    (if ok
        (sys.trim output)
        (or (os.getenv "PWD") "."))))

{: comparison-label
 : diff-entries
 : preview-context
 : preview-output
 : repo-root}
