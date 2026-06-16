(local sys (require :platform.core))

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
        kind (and status (status:sub 1 1))
        path (. parts 2)
        new-path (. parts 3)
        path-entry #(entry status path)]
    (case kind
      "A" (path-entry)
      "M" (path-entry)
      "D" (path-entry)
      "R" (entry "R" new-path path)
      "C" (entry "R" new-path path)
      _ nil)))

(fn parse-name-status [text]
  (icollect [line (string.gmatch (or text "") "[^\r\n]+")]
    (entry-from-name-status-line line)))

(fn diff-command [revision]
  (.. "git diff --name-status --find-renames --find-copies "
      (sys.shell-quote revision) " 2>&1"))

(fn revision-exists? [revision]
  (let [cmd (.. "git rev-parse --verify --quiet "
                (sys.shell-quote (.. revision "^{commit}")) " >/dev/null 2>&1")
        (ok _kind _code) (os.execute cmd)]
    ok))

(fn default-revision []
  (if (revision-exists? "main")
      (values "main" nil)
      (revision-exists? "master")
      (values "master" nil)
      (values nil "No revision provided, and neither main nor master exists.")))

(fn diff-filter []
  (let [cmd "git config --get interactive.diffFilter 2>/dev/null"
        (output ok _kind _code) (sys.read-command cmd)
        filter (sys.trim output)]
    (if (and ok (< 0 (length filter)))
        filter)))

(fn preview-context []
  {:diff-filter (diff-filter)})

(fn current-branch []
  (let [(output ok _kind _code) (sys.read-command "git branch --show-current 2>/dev/null")
        branch (sys.trim output)]
    (if (and ok (> (length branch) 0))
        branch
        "HEAD")))

(fn comparison-revision [revision ?current-branch]
  (let [(left right) (revision:match "^(.-)%.%.%.(.*)$")]
    (if left
        (.. (if (> (length left) 0) left (or ?current-branch (current-branch)))
            "..." (if (> (length right) 0) right
                     (or ?current-branch (current-branch))))
        (.. revision "..." (or ?current-branch (current-branch))))))

(fn comparison-label [revision]
  (comparison-revision revision))

(fn comparison-right [revision ?current-branch]
  (let [current-branch (or ?current-branch (current-branch))
        (_left right) (revision:match "^(.-)%.%.%.(.*)$")]
    (if (and right (> (length right) 0) (not (= right "HEAD")))
        right
        current-branch)))

(fn linked-pr-url-command [branch]
  (.. "gh pr view " (sys.shell-quote branch)
      " --json url --jq .url 2>/dev/null"))

(fn linked-pr-url [revision]
  (let [branch (comparison-right revision)]
    (if (= branch "HEAD")
        (values nil "No branch to check for a linked PR")
        (let [(output ok _kind _code) (sys.read-command (linked-pr-url-command branch))
              url (sys.trim output)]
          (if (and ok (> (length url) 0))
              (values url nil)
              (values nil (.. "No linked PR for " branch)))))))

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
 : comparison-revision
 : comparison-right
 : current-branch
 : default-revision
 : diff-entries
 : linked-pr-url
 : linked-pr-url-command
 : preview-context
 : preview-output
 : repo-root}
