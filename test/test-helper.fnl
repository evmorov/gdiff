(local faith (require :faith))
(local sys (require :platform.core))

(fn output [cmd]
  (let [(out ok) (sys.read-command cmd)]
    (faith.is ok (.. "command failed: " cmd))
    out))

(fn test-root []
  (or (os.getenv "GDIFF_TEST_ROOT") ""))

(fn current-dir []
  (sys.trim (output "pwd")))

(fn ensure-test-root []
  (faith.is (> (length (test-root)) 0) "GDIFF_TEST_ROOT is not set")
  (faith.= (test-root) (current-dir) "tests must run from the temp root"))

(fn sh [cmd]
  (let [(ok _kind _code) (os.execute (.. cmd " >/dev/null 2>&1"))]
    (faith.is ok (.. "command failed: " cmd))))

(fn reset-workdir []
  (ensure-test-root)
  (sh "find . -mindepth 1 -maxdepth 1 -exec rm -rf {} +"))

(fn mkdir [path]
  (faith.is (sys.ensure-dir path) (.. "could not create " path)))

(fn write-file [path contents]
  (faith.is (sys.write-file path contents) (.. "could not write " path)))

(fn init-repo []
  (reset-workdir)
  (sh "git init")
  (sh "git config user.email gdiff@example.test")
  (sh "git config user.name gdiff"))

(fn commit-all [?message]
  (sh "git add .")
  (sh (.. "git commit -m " (sys.shell-quote (or ?message "test")))))

(fn strip-lines [lines]
  (let [tui (require :tui.core)]
    (icollect [_ line (ipairs lines)]
      (tui.strip-ansi line))))

(fn text [lines]
  (table.concat (strip-lines lines) "\n"))

(fn count-pairs [t]
  (accumulate [count 0 _ _ (pairs t)]
    (+ count 1)))

{: commit-all
 : count-pairs
 : init-repo
 : mkdir
 : reset-workdir
 : sh
 : text
 : write-file}
