(local code-stats (require :git.code-stats))
(local faith (require :faith))

(fn patch [lines]
  (.. (table.concat lines "\n") "\n"))

(fn test-parse-counts-added-and-deleted-code-lines []
  (let [stats (code-stats.parse (patch ["diff --git a/src/app.js b/src/app.js"
                                        "index 111..222 100644"
                                        "--- a/src/app.js"
                                        "+++ b/src/app.js"
                                        "@@ -1,2 +1,2 @@"
                                        "-const old = 1"
                                        "+const fresh = 1"
                                        "+const extra = 2"]))]
    (faith.= {:additions 2 :deletions 1} stats)))

(fn test-parse-skips-comment-lines-per-language []
  (let [stats (code-stats.parse (patch ["--- a/src/app.js"
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
    (faith.= {:additions 3 :deletions 0} stats)))

(fn test-parse-skips-markdown-files-and-blank-lines []
  (let [stats (code-stats.parse (patch ["--- a/README.md"
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
    (faith.= {:additions 1 :deletions 0} stats)))

(fn test-parse-counts-hash-lines-in-unknown-file-types []
  (let [stats (code-stats.parse (patch ["--- a/notes.txt"
                                        "+++ b/notes.txt"
                                        "@@ -1,1 +1,1 @@"
                                        "+# not a comment here"]))]
    (faith.= {:additions 1 :deletions 0} stats)))

(fn test-parse-uses-old-path-for-deleted-files []
  (let [stats (code-stats.parse (patch ["diff --git a/gone.py b/gone.py"
                                        "deleted file mode 100644"
                                        "--- a/gone.py"
                                        "+++ /dev/null"
                                        "@@ -1,2 +0,0 @@"
                                        "-# comment"
                                        "-print(1)"]))]
    (faith.= {:additions 0 :deletions 1} stats)))

(fn test-parse-handles-fennel-and-yaml []
  (let [stats (code-stats.parse (patch ["--- a/src/main.fnl"
                                        "+++ b/src/main.fnl"
                                        "@@ -1,1 +1,2 @@"
                                        "+;; explain"
                                        "+(print :hi)"
                                        "--- a/config.yml"
                                        "+++ b/config.yml"
                                        "@@ -1,1 +1,2 @@"
                                        "+# comment"
                                        "+key: value"]))]
    (faith.= {:additions 2 :deletions 0} stats)))

(fn test-parse-handles-empty-input []
  (faith.= {:additions 0 :deletions 0} (code-stats.parse nil))
  (faith.= {:additions 0 :deletions 0} (code-stats.parse "")))

{: test-parse-counts-added-and-deleted-code-lines
 : test-parse-counts-hash-lines-in-unknown-file-types
 : test-parse-handles-empty-input
 : test-parse-handles-fennel-and-yaml
 : test-parse-skips-comment-lines-per-language
 : test-parse-skips-markdown-files-and-blank-lines
 : test-parse-uses-old-path-for-deleted-files}
