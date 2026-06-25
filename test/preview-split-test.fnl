(local faith (require :faith))
(local split (require :preview.split))

(local sample (table.concat ["diff --git a/f b/f"
                             "index 111..222 100644"
                             "--- a/f"
                             "+++ b/f"
                             "@@ -1,3 +1,3 @@"
                             " ctx"
                             "-old line"
                             "+new line"
                             " tail"] "\n"))

(fn test-parse-rows-replaces-headers-with-a-filename-title []
  (faith.= [{:kind :filename :old "f" :new "f"}
            {:kind :rule :old "f" :new "f"}
            {:kind :hunk :old "@@ -1,3 +1,3 @@"}
            {:kind :context :old "ctx" :new "ctx"}
            {:kind :change :old "old line" :new "new line"}
            {:kind :context :old "tail" :new "tail"}]
           (split.parse-rows sample)))

(fn test-parse-rows-labels-each-column-with-its-ref []
  (let [rows (split.parse-rows sample "main" "feature")]
    (faith.= {:kind :filename :old "f (main)" :new "f (feature)"} (. rows 1))
    (faith.= {:kind :rule :old "f (main)" :new "f (feature)"} (. rows 2))))

(fn test-parse-rows-handles-pure-additions []
  (faith.= [{:kind :hunk :old "@@ -0,0 +1,2 @@"}
            {:kind :change :new "a"}
            {:kind :change :new "b"}]
           (split.parse-rows "@@ -0,0 +1,2 @@\n+a\n+b")))

(fn test-parse-rows-handles-pure-deletions []
  (faith.= [{:kind :hunk :old "@@ -1,2 +0,0 @@"}
            {:kind :change :old "a"}
            {:kind :change :old "b"}]
           (split.parse-rows "@@ -1,2 +0,0 @@\n-a\n-b")))

(fn test-parse-rows-pairs-uneven-runs []
  (faith.= [{:kind :hunk :old "@@ -1,2 +1,1 @@"}
            {:kind :change :old "x" :new "z"}
            {:kind :change :old "y"}]
           (split.parse-rows "@@ -1,2 +1,1 @@\n-x\n-y\n+z")))

(fn test-splittable-detects-real-diffs []
  (faith.is (split.splittable? (split.parse-rows sample))))

(fn test-not-splittable-for-binary-or-empty []
  (faith.is (not (split.splittable? (split.parse-rows "diff --git a/x b/x\nBinary files a/x and b/x differ"))))
  (faith.is (not (split.splittable? (split.parse-rows ""))))
  (faith.is (not (split.splittable? []))))

{: test-parse-rows-replaces-headers-with-a-filename-title
 : test-parse-rows-labels-each-column-with-its-ref
 : test-parse-rows-handles-pure-additions
 : test-parse-rows-handles-pure-deletions
 : test-parse-rows-pairs-uneven-runs
 : test-splittable-detects-real-diffs
 : test-not-splittable-for-binary-or-empty}
