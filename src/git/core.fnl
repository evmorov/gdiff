(local commands (require :git.commands))
(local blame (require :git.blame))
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

(fn comparison-sides [revision ?current-branch]
  (if (commands.working? revision)
      (values "HEAD" "working tree")
      (let [current (or ?current-branch (current-branch))
            (left right) (revision:match "^(.-)%.%.%.(.*)$")]
        (if left
            (values (if (> (length left) 0) left current)
                    (if (> (length right) 0) right current))
            (values revision current)))))

(fn comparison-revision [revision ?current-branch]
  (if (commands.working? revision) revision
      (let [(left right) (comparison-sides revision ?current-branch)]
        (.. left "..." right))))

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

(fn split-revision [revision]
  (revision:match "^(.-)%.%.%.(.*)$"))

(fn comparison-ref-targets [revision]
  (if (commands.working? revision)
      (values "HEAD" nil)
      (let [(left right) (split-revision revision)]
        (if left
            (values (if (> (length left) 0) left (current-branch))
                    (if (> (length right) 0) right "HEAD"))
            (values revision nil)))))

(fn blame-target [revision entry side]
  (let [(old-ref new-ref) (comparison-ref-targets revision)]
    (if (= side :old)
        (values old-ref (or entry.old_path entry.path))
        (values new-ref entry.path))))

(fn blame-lines [revision entry side]
  (let [(?ref path) (blame-target revision entry side)]
    (if (not path)
        {}
        (let [(output ok) (sys.read-command (commands.blame-command ?ref path))]
          (if ok (blame.parse output) {})))))

(fn repo-root []
  (or (read-trimmed (commands.repo-root-command)) (os.getenv "PWD") "."))

(fn base-ref [revision]
  (let [(left _right) (comparison-sides revision)]
    left))

(fn temp-root []
  (let [tmp (or (os.getenv "TMPDIR") "/tmp")]
    (if (= (tmp:sub -1) "/") (tmp:sub 1 -2) tmp)))

(fn parent-dir [path]
  (or (path:match "^(.*)/[^/]*$") "."))

(fn materialize-base [ref path]
  (let [(content ok) (sys.read-command (commands.show-file-command ref path))]
    (if ok
        (let [temp (commands.base-temp-path (temp-root) ref path)]
          (sys.ensure-dir (parent-dir temp))
          (if (sys.write-file temp content)
              (values temp nil)
              (values nil "Could not write base snapshot")))
        (values nil (.. "Not in " ref)))))

{: base-ref
 : blame-lines
 : comparison-revision
 : comparison-right
 : comparison-sides
 : current-branch
 : default-revision
 : diff-entries
 : diff-stats
 : diff-stats-command
 : linked-pr-url
 : linked-pr-url-command
 : materialize-base
 :working-revision commands.working-revision
 :working? commands.working?
 : plain-diff-output
 : repo-root}
