(local commands (require :git.commands))
(local parse (require :git.parse))
(local sys (require :platform.core))

(local diff-stats-command commands.diff-stats-command)
(local linked-pr-url-command commands.linked-pr-url-command)

(fn revision-exists? [revision]
  (let [(ok _kind _code) (os.execute (commands.revision-exists-command revision))]
    ok))

(fn default-revision []
  (if (revision-exists? "main")
      (values "main" nil)
      (revision-exists? "master")
      (values "master" nil)
      (values nil "No revision provided, and neither main nor master exists.")))

(fn diff-filter []
  (let [(output ok _kind _code) (sys.read-command (commands.diff-filter-command))
        filter (sys.trim output)]
    (if (and ok (< 0 (length filter)))
        filter)))

(fn preview-context []
  {:diff-filter (diff-filter)})

(fn current-branch []
  (let [(output ok _kind _code) (sys.read-command (commands.current-branch-command))
        branch (sys.trim output)]
    (if (and ok (> (length branch) 0))
        branch
        "HEAD")))

(fn comparison-revision [revision ?current-branch]
  (if (commands.working? revision) revision
      (let [(left right) (revision:match "^(.-)%.%.%.(.*)$")]
        (if left
            (.. (if (> (length left) 0) left
                    (or ?current-branch (current-branch)))
                "..."
                (if (> (length right) 0) right
                    (or ?current-branch (current-branch))))
            (.. revision "..." (or ?current-branch (current-branch)))))))

(fn comparison-right [revision ?current-branch]
  (let [current-branch (or ?current-branch (current-branch))
        (_left right) (revision:match "^(.-)%.%.%.(.*)$")]
    (if (and right (> (length right) 0) (not (= right "HEAD")))
        right
        current-branch)))

(fn linked-pr-url [revision]
  (let [branch (comparison-right revision)]
    (if (= branch "HEAD")
        (values nil "No branch to check for a linked PR")
        (let [(output ok _kind _code) (sys.read-command (linked-pr-url-command branch))
              url (sys.trim output)]
          (if (and ok (> (length url) 0))
              (values url nil)
              (values nil (.. "No linked PR for " branch)))))))

(fn read-output [cmd]
  (let [(output ok _kind _code) (sys.read-command cmd)]
    (if ok output "")))

(fn working-entries [name-status]
  (parse.parse-working name-status
                       (read-output (commands.staged-paths-command))
                       (read-output (commands.untracked-command))))

(fn diff-entries [revision]
  (let [(output ok _kind _code) (sys.read-command (commands.diff-command revision))]
    (if ok
        (if (commands.working? revision)
            (values (working-entries output) nil)
            (values (parse.parse-name-status output) nil))
        (values nil (sys.trim output)))))

(fn diff-stats [revision]
  (let [(output ok _kind _code) (sys.read-command (commands.diff-stats-command revision))]
    (if ok
        (values (parse.parse-numstat output) nil)
        (values nil (sys.trim output)))))

(fn preview-output [context revision entry ?full-context?]
  (let [filter context.diff-filter]
    (if filter
        (let [(output ok _kind _code) (sys.read-command (commands.filtered-preview-command revision
                                                                                           entry
                                                                                           filter
                                                                                           ?full-context?))]
          (if ok
              (values output true true)
              (let [(output ok _kind _code) (sys.read-command (commands.plain-preview-command revision
                                                                                              entry
                                                                                              ?full-context?))]
                (values output ok false))))
        (let [(output ok _kind _code) (sys.read-command (commands.plain-preview-command revision
                                                                                        entry
                                                                                        ?full-context?))]
          (values output ok false)))))

(fn repo-root []
  (let [(output ok _kind _code) (sys.read-command (commands.repo-root-command))]
    (if ok
        (sys.trim output)
        (or (os.getenv "PWD") "."))))

{: comparison-revision
 : comparison-right
 : current-branch
 : default-revision
 : diff-entries
 : diff-stats
 : diff-stats-command
 : linked-pr-url
 : linked-pr-url-command
 : preview-context
 :working-revision commands.working-revision
 :working? commands.working?
 : preview-output
 : repo-root}
