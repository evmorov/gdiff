(local commands (require :git.commands))
(local parse (require :git.parse))
(local sys (require :platform.core))

(local diff-stats-command commands.diff-stats-command)
(local linked-pr-url-command commands.linked-pr-url-command)

(fn read-trimmed [cmd]
  (let [(output ok) (sys.read-command cmd)
        text (sys.trim output)]
    (if (and ok (> (length text) 0)) text)))

(fn run-result [cmd ok-fn]
  (let [(output ok) (sys.read-command cmd)]
    (if ok
        (ok-fn output)
        (values nil (sys.trim output)))))

(fn revision-exists? [revision]
  (let [(ok _kind _code) (os.execute (commands.revision-exists-command revision))]
    ok))

(fn default-revision []
  (if (revision-exists? "main")
      (values "main" nil)
      (revision-exists? "master")
      (values "master" nil)
      (values nil "No revision provided, and neither main nor master exists.")))

(fn current-branch []
  (or (read-trimmed (commands.current-branch-command)) "HEAD"))

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

(fn comparison-sides [revision ?current-branch]
  (if (commands.working? revision)
      (values "HEAD" "working tree")
      (let [current (or ?current-branch (current-branch))
            (left right) (revision:match "^(.-)%.%.%.(.*)$")]
        (if left
            (values (if (> (length left) 0) left current)
                    (if (> (length right) 0) right current))
            (values revision current)))))

(fn linked-pr-url [revision]
  (let [branch (comparison-right revision)]
    (if (= branch "HEAD")
        (values nil "No branch to check for a linked PR")
        (let [url (read-trimmed (linked-pr-url-command branch))]
          (if url
              (values url nil)
              (values nil (.. "No linked PR for " branch)))))))

(fn read-output [cmd]
  (let [(output ok) (sys.read-command cmd)]
    (if ok output "")))

(fn working-entries [name-status]
  (parse.parse-working name-status
                       (read-output (commands.staged-paths-command))
                       (read-output (commands.untracked-command))))

(fn diff-entries [revision]
  (run-result (commands.diff-command revision)
              (fn [output]
                (if (commands.working? revision)
                    (values (working-entries output) nil)
                    (values (parse.parse-name-status output) nil)))))

(fn diff-stats [revision]
  (run-result (commands.diff-stats-command revision)
              #(values (parse.parse-numstat $) nil)))

(fn plain-diff-output [revision entry ?full-context?]
  (sys.read-command (commands.plain-preview-command revision entry
                                                    ?full-context?)))

(fn repo-root []
  (or (read-trimmed (commands.repo-root-command)) (os.getenv "PWD") "."))

{: comparison-revision
 : comparison-right
 : comparison-sides
 : current-branch
 : default-revision
 : diff-entries
 : diff-stats
 : diff-stats-command
 : linked-pr-url
 : linked-pr-url-command
 :working-revision commands.working-revision
 :working? commands.working?
 : plain-diff-output
 : repo-root}
