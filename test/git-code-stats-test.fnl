(local code-stats (require :git.code-stats))
(local faith (require :faith))

(fn patch [lines]
  (.. (table.concat lines "\n") "\n"))

(fn stats [additions deletions ?no-tests-additions ?no-tests-deletions]
  {: additions
   : deletions
   :no_tests_additions (or ?no-tests-additions additions)
   :no_tests_deletions (or ?no-tests-deletions deletions)})

(fn test-parse-counts-added-and-deleted-code-lines []
  (let [result (code-stats.parse (patch ["diff --git a/src/app.js b/src/app.js"
                                         "index 111..222 100644"
                                         "--- a/src/app.js"
                                         "+++ b/src/app.js"
                                         "@@ -1,2 +1,2 @@"
                                         "-const old = 1"
                                         "+const fresh = 1"
                                         "+const extra = 2"]))]
    (faith.= (stats 2 1) result)))

(fn test-parse-skips-comment-lines-per-language []
  (let [result (code-stats.parse (patch ["--- a/src/app.js"
                                         "+++ b/src/app.js"
                                         "@@ -1,3 +1,4 @@"
                                         "+// explain"
                                         "+/* block */"
                                         "+ * continued"
                                         "+const a = 1"
                                         "--- a/lib/task.rb"
                                         "+++ b/lib/task.rb"
                                         "@@ -1,2 +1,2 @@"
                                         "+# note"
                                         "-# old note"
                                         "+puts 1"
                                         "--- a/init.lua"
                                         "+++ b/init.lua"
                                         "@@ -1,1 +1,2 @@"
                                         "+-- setup"
                                         "+return {}"]))]
    (faith.= (stats 3 0) result)))

(fn test-parse-skips-markdown-files-and-blank-lines []
  (let [result (code-stats.parse (patch ["--- a/README.md"
                                         "+++ b/README.md"
                                         "@@ -1,1 +1,2 @@"
                                         "+# heading"
                                         "+prose"
                                         "--- a/src/app.rb"
                                         "+++ b/src/app.rb"
                                         "@@ -1,1 +1,3 @@"
                                         "+puts 1"
                                         "+"
                                         "-   "]))]
    (faith.= (stats 1 0) result)))

(fn test-parse-skips-comments-in-well-known-extensionless-files []
  (let [result (code-stats.parse (patch ["--- a/Gemfile"
                                         "+++ b/Gemfile"
                                         "@@ -1,1 +1,2 @@"
                                         "+# gems"
                                         "+gem \"faith\""
                                         "--- a/Dockerfile"
                                         "+++ b/Dockerfile"
                                         "@@ -1,1 +1,2 @@"
                                         "+# base image"
                                         "+FROM ruby"]))]
    (faith.= (stats 2 0) result)))

(fn test-parse-counts-hash-lines-in-unknown-file-types []
  (let [result (code-stats.parse (patch ["--- a/notes.txt"
                                         "+++ b/notes.txt"
                                         "@@ -1,1 +1,1 @@"
                                         "+# not a comment here"]))]
    (faith.= (stats 1 0) result)))

(fn test-parse-uses-old-path-for-deleted-files []
  (let [result (code-stats.parse (patch ["diff --git a/gone.py b/gone.py"
                                         "deleted file mode 100644"
                                         "--- a/gone.py"
                                         "+++ /dev/null"
                                         "@@ -1,2 +0,0 @@"
                                         "-# comment"
                                         "-print(1)"]))]
    (faith.= (stats 0 1) result)))

(fn test-parse-handles-fennel-and-yaml []
  (let [result (code-stats.parse (patch ["--- a/src/main.fnl"
                                         "+++ b/src/main.fnl"
                                         "@@ -1,1 +1,2 @@"
                                         "+;; explain"
                                         "+(print :hi)"
                                         "--- a/config.yml"
                                         "+++ b/config.yml"
                                         "@@ -1,1 +1,2 @@"
                                         "+# comment"
                                         "+key: value"]))]
    (faith.= (stats 2 0) result)))

(fn test-parse-excludes-test-folders-from-no-tests-counts []
  (let [result (code-stats.parse (patch ["--- a/spec/app_spec.rb"
                                         "+++ b/spec/app_spec.rb"
                                         "@@ -1,1 +1,1 @@"
                                         "+expect(fresh)"
                                         "-expect(old)"
                                         "--- a/src/__tests__/app.js"
                                         "+++ b/src/__tests__/app.js"
                                         "@@ -1,1 +1,2 @@"
                                         "+it(\"works\")"
                                         "--- a/lib/Test/case.rb"
                                         "+++ b/lib/Test/case.rb"
                                         "@@ -1,1 +1,2 @@"
                                         "+puts 2"
                                         "--- a/src/app.rb"
                                         "+++ b/src/app.rb"
                                         "@@ -1,1 +1,2 @@"
                                         "+puts 1"]))]
    (faith.= (stats 4 1 1 0) result)))

(fn test-test-path-matches-folders-not-file-names []
  (faith.= true (code-stats.test-path? "test/app.rb"))
  (faith.= true (code-stats.test-path? "src/e2e/login.ts"))
  (faith.= false (code-stats.test-path? "src/app_test.rb"))
  (faith.= false (code-stats.test-path? "src/testdata/app.rb"))
  (faith.= false (code-stats.test-path? "contest/app.rb")))

(fn test-parse-handles-empty-input []
  (faith.= (stats 0 0) (code-stats.parse nil))
  (faith.= (stats 0 0) (code-stats.parse "")))

{: test-parse-counts-added-and-deleted-code-lines
 : test-parse-counts-hash-lines-in-unknown-file-types
 : test-parse-skips-comments-in-well-known-extensionless-files
 : test-parse-excludes-test-folders-from-no-tests-counts
 : test-parse-handles-empty-input
 : test-parse-handles-fennel-and-yaml
 : test-parse-skips-comment-lines-per-language
 : test-parse-skips-markdown-files-and-blank-lines
 : test-parse-uses-old-path-for-deleted-files
 : test-test-path-matches-folders-not-file-names}
