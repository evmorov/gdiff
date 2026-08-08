(local commands (require :git.commands))
(local blame (require :git.blame))
(local code-stats (require :git.code-stats))
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

(fn local-branch? [branch]
  (let [(ok _kind _code) (os.execute (commands.local-branch-command branch))]
    ok))

(fn comparison-sides [revision ?current-branch]
  (if (commands.files? revision)
      (commands.files-paths revision)
      (commands.working? revision)
      (values "HEAD" "working tree")
      (let [current (or ?current-branch (current-branch))
            (left right) (revision:match "^(.-)%.%.%.(.*)$")]
        (if left
            (values (if (> (length left) 0) left current)
                    (if (> (length right) 0) right current))
            (values revision current)))))

(fn comparison-revision [revision ?current-branch]
  (if (or (commands.working? revision) (commands.files? revision)) revision
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

(fn resolve-commit [revision]
  (read-trimmed (commands.resolve-commit-command revision)))

(fn merge-base [left right]
  (read-trimmed (commands.merge-base-command left right)))

(fn diff-base-ref [revision]
  "The ref whose file contents the old side of the diff shows: the merge base
for three-dot ranges, the revision itself otherwise."
  (if (commands.working? revision) "HEAD" (commands.files? revision)
      (pick-values 1 (commands.files-paths revision))
      (let [(left right) (comparison-sides revision)]
        (if (revision:match "%.%.%.")
            (or (merge-base left right) left)
            left))))

(fn parse-pr-info [output]
  (let [lines (icollect [line (output:gmatch "[^\n]+")] line)
        [base-branch head-branch head-oid] lines]
    (when (and base-branch head-branch head-oid)
      {: base-branch : head-branch : head-oid})))

(fn pr-info [pr]
  (let [(output ok) (sys.read-command (commands.pr-info-command pr.url))
        info (and ok (parse-pr-info output))]
    (if info
        (values info nil)
        (values nil
                (.. "Could not read PR info for " pr.url
                    " (is gh installed and authenticated?)")))))

(fn fetch [cmd]
  (let [(output ok) (sys.read-command cmd)]
    (if ok
        true
        (values nil (sys.trim output)))))

(fn pr-remote-head-ref [info]
  (let [remote (.. "origin/" info.head-branch)]
    (fetch (commands.fetch-branch-command info.head-branch))
    (when (= info.head-oid (resolve-commit remote))
      remote)))

(fn pr-head-ref [pr info]
  (let [remote (pr-remote-head-ref info)]
    (if remote (values remote nil) (resolve-commit info.head-oid)
        (values info.head-oid nil)
        (let [(ok err) (fetch (commands.fetch-pr-head-command pr.number))]
          (if (and ok (resolve-commit info.head-oid))
              (values info.head-oid nil)
              (values nil (or err
                              (.. "Could not fetch PR #" pr.number
                                  " from origin"))))))))

(fn pr-base-ref [info]
  (let [remote (.. "origin/" info.base-branch)
        (_fetched fetch-err) (fetch (commands.fetch-branch-command info.base-branch))]
    (if (resolve-commit remote) (values remote nil)
        (values nil (or fetch-err (.. "Could not resolve " info.base-branch))))))

(fn pr-revision-from-info [pr info]
  (let [(head head-err) (pr-head-ref pr info)]
    (if (not head)
        (values nil head-err)
        (let [(base base-err) (pr-base-ref info)]
          (if (not base)
              (values nil base-err)
              (values (.. base "..." head) nil))))))

(fn resolve-pr-revision [pr]
  (let [(info err) (pr-info pr)]
    (if (not info)
        (values nil err)
        (pr-revision-from-info pr info))))

(fn pr-fetched-head-ref [info]
  (let [remote (.. "origin/" info.head-branch)]
    (if (= info.head-oid (resolve-commit remote)) remote
        (resolve-commit info.head-oid) info.head-oid)))

(fn pr-revision-from-fetched-info [info]
  "Resolve a PR revision from refs that were already fetched, without network."
  (let [base (.. "origin/" info.base-branch)
        head (pr-fetched-head-ref info)]
    (if (not head) (values nil "Could not resolve PR head")
        (not (resolve-commit base))
        (values nil (.. "Could not resolve " info.base-branch))
        (values (.. base "..." head) nil))))

(fn read-output [cmd]
  (let [(output ok) (sys.read-command cmd)]
    (if ok output "")))

(fn working-entries [name-status]
  (parse.parse-working name-status
                       (read-output (commands.staged-paths-command))
                       (read-output (commands.untracked-command))))

(fn files-entries [revision output]
  (let [(left right) (commands.files-paths revision)]
    (parse.parse-no-index output left right (sys.dir-exists? right))))

(fn diff-entries [revision]
  (run-result (commands.diff-command revision)
              (fn [output]
                (if (commands.files? revision)
                    (values (files-entries revision output) nil)
                    (commands.working? revision)
                    (values (working-entries output) nil)
                    (values (parse.parse-name-status output) nil)))))

(fn code-diff-stats [revision]
  (let [(output ok) (sys.read-command (commands.diff-patch-command revision))]
    (when ok (code-stats.parse output))))

(fn diff-stats [revision]
  (run-result (commands.diff-stats-command revision)
              (fn [output]
                (let [stats (parse.parse-numstat output)
                      ?code (code-diff-stats revision)]
                  (when ?code
                    (set stats.code_additions ?code.additions)
                    (set stats.code_deletions ?code.deletions)
                    (set stats.comment_additions ?code.comment_additions)
                    (set stats.comment_deletions ?code.comment_deletions)
                    (set stats.no_tests_additions ?code.no_tests_additions)
                    (set stats.no_tests_deletions ?code.no_tests_deletions))
                  (values stats nil)))))

(fn plain-diff-output [revision entry ?full-context?]
  (sys.read-command (commands.plain-preview-command revision entry
                                                    ?full-context?)))

(fn split-revision [revision]
  (revision:match "^(.-)%.%.%.(.*)$"))

(fn comparison-ref-targets [revision]
  (if (commands.files? revision)
      (values nil nil)
      (commands.working? revision)
      (values "HEAD" nil)
      (let [(left right) (split-revision revision)]
        (if left
            (values (diff-base-ref revision)
                    (if (> (length right) 0) right "HEAD"))
            (values revision nil)))))

(fn blame-target [revision entry side]
  (let [(old-ref new-ref) (comparison-ref-targets revision)]
    (if (= side :old)
        (values old-ref (or entry.old_path entry.path))
        (values new-ref entry.path))))

(fn blame-lines [revision entry side ?ranges]
  (let [(?ref path) (blame-target revision entry side)]
    (if (not path)
        {}
        (let [(output ok) (sys.read-command (commands.blame-command ?ref path
                                                                    ?ranges))]
          (if ok (blame.parse output) {})))))

(fn blame-commit [revision entry side line]
  "Resolve the commit that last touched a single diff line via git blame."
  (let [(?ref path) (blame-target revision entry side)]
    (if (not path)
        (values nil "No file to blame")
        (let [(output ok) (sys.read-command (commands.blame-command ?ref path
                                                                    [[line
                                                                      line]]))
              sha (and ok (blame.commit output))]
          (if (not sha) (values nil "Could not blame this line")
              (blame.uncommitted? sha) (values nil "Line is not committed yet")
              (values sha nil))))))

(fn commit-url [sha]
  (let [url (read-trimmed (commands.commit-url-command sha))]
    (if url
        (values url nil)
        (values nil "Could not resolve commit URL"))))

(fn repo-root []
  (or (read-trimmed (commands.repo-root-command)) (os.getenv "PWD") "."))

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

{: blame-commit
 : blame-lines
 : commit-url
 : comparison-revision
 : comparison-right
 : comparison-sides
 : current-branch
 : default-revision
 : diff-base-ref
 : diff-entries
 : diff-stats
 : diff-stats-command
 : linked-pr-url
 : linked-pr-url-command
 : local-branch?
 : materialize-base
 : parse-pr-info
 : pr-revision-from-fetched-info
 : pr-revision-from-info
 : resolve-pr-revision
 :working-revision commands.working-revision
 :working? commands.working?
 :files-revision commands.files-revision
 :files-paths commands.files-paths
 :files? commands.files?
 : plain-diff-output
 : repo-root}
