(local faith (require :faith))
(local split (require :preview.split))
(local word-diff (require :preview.word-diff))

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
            {:kind :context :old "ctx" :new "ctx" :old-no 1 :new-no 1}
            {:kind :change
             :old "old line"
             :new "new line"
             :old-no 2
             :new-no 2
             :emphasize? true
             :spans (word-diff.spans "old line" "new line")}
            {:kind :context :old "tail" :new "tail" :old-no 3 :new-no 3}]
           (split.parse-rows sample)))

(fn test-parse-rows-labels-each-column-with-its-ref []
  (let [rows (split.parse-rows sample "main" "feature")]
    (faith.= {:kind :filename :old "f (main)" :new "f (feature)"} (. rows 1))
    (faith.= {:kind :rule :old "f (main)" :new "f (feature)"} (. rows 2))))

(fn test-parse-rows-handles-pure-additions []
  (faith.= [{:kind :hunk :old "@@ -0,0 +1,2 @@"}
            {:kind :change :new "a" :new-no 1}
            {:kind :change :new "b" :new-no 2}]
           (split.parse-rows "@@ -0,0 +1,2 @@\n+a\n+b")))

(fn test-parse-rows-handles-pure-deletions []
  (faith.= [{:kind :hunk :old "@@ -1,2 +0,0 @@"}
            {:kind :change :old "a" :old-no 1}
            {:kind :change :old "b" :old-no 2}]
           (split.parse-rows "@@ -1,2 +0,0 @@\n-a\n-b")))

(fn test-parse-rows-pairs-uneven-runs []
  (faith.= [{:kind :hunk :old "@@ -1,2 +1,1 @@"}
            {:kind :change :old "x" :old-no 1}
            {:kind :change :old "y" :old-no 2}
            {:kind :change :new "z" :new-no 1}]
           (split.parse-rows "@@ -1,2 +1,1 @@\n-x\n-y\n+z")))

(fn test-parse-rows-aligns-similar-lines-onto-one-row []
  (faith.= [{:kind :hunk :old "@@ -1,1 +1,2 @@"}
            {:kind :change
             :old "keep aaa tail"
             :new "keep bbb tail"
             :old-no 1
             :new-no 1
             :emphasize? true
             :spans (word-diff.spans "keep aaa tail" "keep bbb tail")}
            {:kind :change :new "brand new line" :new-no 2}]
           (split.parse-rows "@@ -1,1 +1,2 @@\n-keep aaa tail\n+keep bbb tail\n+brand new line")))

(fn test-parse-rows-tags-whitespace-only-hunks []
  (let [rows (split.parse-rows (.. "@@ -1,2 +1,1 @@\n ctx\n-\n"
                                   "@@ -10,2 +9,2 @@\n-a\n+b\n-"))
        change-rows (icollect [_ row (ipairs rows)]
                      (when (= row.kind :change) row))]
    (faith.= {:kind :change :old "" :old-no 2 :whitespace-hunk? true}
             (. change-rows 1))
    (faith.= nil (. change-rows 2 :whitespace-hunk?))
    (faith.= nil (. change-rows 3 :whitespace-hunk?))))

(fn test-splittable-detects-real-diffs []
  (faith.is (split.splittable? (split.parse-rows sample))))

(fn test-not-splittable-for-binary-or-empty []
  (faith.is (not (split.splittable? (split.parse-rows "diff --git a/x b/x\nBinary files a/x and b/x differ"))))
  (faith.is (not (split.splittable? (split.parse-rows ""))))
  (faith.is (not (split.splittable? []))))

(fn test-not-splittable-for-one-sided-changes []
  (faith.is (not (split.splittable? (split.parse-rows "@@ -0,0 +1,2 @@\n+a\n+b"))))
  (faith.is (not (split.splittable? (split.parse-rows "@@ -1,2 +0,0 @@\n-a\n-b")))))

{: test-parse-rows-replaces-headers-with-a-filename-title
 : test-parse-rows-labels-each-column-with-its-ref
 : test-parse-rows-handles-pure-additions
 : test-parse-rows-handles-pure-deletions
 : test-parse-rows-pairs-uneven-runs
 : test-parse-rows-aligns-similar-lines-onto-one-row
 : test-parse-rows-tags-whitespace-only-hunks
 : test-splittable-detects-real-diffs
 : test-not-splittable-for-binary-or-empty
 : test-not-splittable-for-one-sided-changes}
