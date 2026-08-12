(local faith (require :faith))
(local parse (require :git.parse))

(fn first-entry [text]
  (. (parse.parse-name-status text) 1))

(fn test-name-status-parses-simple-entry []
  (faith.= {:kind "M"
            :old_path nil
            :path "src/app.fnl"
            :reviewed false
            :status "M"} (first-entry "M\tsrc/app.fnl\n")))

(fn test-name-status-parses-renames-as-renames []
  (faith.= {:kind "R"
            :old_path "spec/acme/api_spec.rb"
            :path "spec/acme/api/v2_spec.rb"
            :reviewed false
            :status "R"}
           (first-entry "R057\tspec/acme/api_spec.rb\tspec/acme/api/v2_spec.rb\n")))

(fn test-name-status-treats-copies-as-rename-entries []
  (faith.= {:kind "R"
            :old_path "old.fnl"
            :path "new.fnl"
            :reviewed false
            :status "R"} (first-entry "C057\told.fnl\tnew.fnl\n")))

(fn test-no-index-parses-folder-comparison-lines []
  (let [text "A\t./new/added.txt\nM\told/sub/mod.txt\nD\told/removed.txt\n"
        entries (parse.parse-no-index text "old/" "./new" true)]
    (faith.= {:kind "A"
              :new_file "./new/added.txt"
              :path "added.txt"
              :reviewed false
              :status "A"} (. entries 1))
    (faith.= {:kind "M"
              :new_file "./new/sub/mod.txt"
              :old_file "old/sub/mod.txt"
              :path "sub/mod.txt"
              :reviewed false
              :status "M"} (. entries 2))
    (faith.= {:kind "D"
              :old_file "old/removed.txt"
              :path "removed.txt"
              :reviewed false
              :status "D"} (. entries 3))))

(fn test-no-index-keeps-single-file-comparison-entry []
  (faith.= {:kind "M"
            :new_file "new.txt"
            :old_file "old.txt"
            :old_path "old.txt"
            :path "new.txt"
            :reviewed false
            :status "M"} (. (parse.parse-no-index "M\told.txt\n"
                                                             "old.txt" "new.txt"
                                                             false)
                                       1)))

(fn test-no-index-folder-to-file-diffs-against-the-file []
  (faith.= {:kind "M"
            :new_file "elsewhere/mod.txt"
            :old_file "old/mod.txt"
            :path "mod.txt"
            :reviewed false
            :status "M"} (. (parse.parse-no-index "M\told/mod.txt\n"
                                                             "old"
                                                             "elsewhere/mod.txt"
                                                             false)
                                       1)))

(fn test-no-index-ignores-lines-that-are-not-name-status []
  (faith.= [] (parse.parse-no-index "error: Could not access 'x'\n" "a" "b"
                                    true)))

(fn test-numstat-collects-totals-and-file-stats []
  (let [stats (parse.parse-numstat "2\t1\tsrc/app.fnl\n-\t-\timage.png\n")]
    (faith.= 2 stats.additions)
    (faith.= 1 stats.deletions)
    (faith.= {:additions 2 :deletions 1} (. stats.files "src/app.fnl"))
    (faith.= nil (. stats.files "image.png"))))

(fn test-numstat-indexes-braced-rename-target []
  (let [stats (parse.parse-numstat "1\t0\tspec/acme/{api_spec.rb => api/v2_spec.rb}\n")]
    (faith.= {:additions 1 :deletions 0}
             (. stats.files "spec/acme/api/v2_spec.rb"))))

(fn staging-by-path [entries]
  (collect [_ entry (ipairs entries)]
    (values entry.path
            {:kind entry.kind
             :status entry.status
             :unstaged? (= true entry.unstaged?)
             :untracked? (= true entry.untracked?)})))

(fn test-working-marks-entries-absent-from-staged-set-as-unstaged []
  (faith.= {"staged.rb" {:kind "M"
                         :status "M"
                         :unstaged? false
                         :untracked? false}
            "dirty.rb" {:kind "M"
                        :status "M"
                        :unstaged? true
                        :untracked? false}
            "fresh.rb" {:kind "A" :status "A" :unstaged? true :untracked? true}}
           (staging-by-path (parse.parse-working "M\tstaged.rb\nM\tdirty.rb\n"
                                                 "staged.rb\n" "fresh.rb\n"))))

(fn test-working-keeps-real-kind-for-staged-rename []
  (faith.= {:kind "R"
            :old_path "old.rb"
            :path "new.rb"
            :reviewed false
            :status "R"
            :unstaged? nil
            :untracked? nil}
           (. (parse.parse-working "R100\told.rb\tnew.rb\n" "new.rb\n" "") 1)))

(fn test-path-set-collects-lines []
  (faith.= {"a.rb" true "b.rb" true} (parse.parse-path-set "a.rb\nb.rb\n"))
  (faith.= {} (parse.parse-path-set "")))

(fn test-cat-file-batch-parses-blob-records-in-order []
  (faith.= [{:content "hello"} {:content "abc"}]
           (parse.parse-cat-file-batch "1a2b blob 5\nhello\n3c4d blob 3\nabc\n")))

(fn test-cat-file-batch-splits-content-by-size-not-lines []
  (faith.= [{:content "line1\nline2"} {:content "a\0b"}]
           (parse.parse-cat-file-batch "1a2b blob 11\nline1\nline2\n3c4d blob 3\na\0b\n")))

(fn test-cat-file-batch-keeps-missing-records-positional []
  (faith.= [{:content "one"} {:missing true} {:content "two"}]
           (parse.parse-cat-file-batch "1a2b blob 3\none\nHEAD:no such.txt missing\n3c4d blob 3\ntwo\n")))

(fn test-cat-file-batch-treats-non-blob-objects-as-missing []
  (faith.= [{:missing true} {:content "ok"}]
           (parse.parse-cat-file-batch "1a2b tree 4\nxxxx\n3c4d blob 2\nok\n")))

(fn test-cat-file-batch-handles-empty-output []
  (faith.= [] (parse.parse-cat-file-batch "")))

{: test-cat-file-batch-handles-empty-output
 : test-cat-file-batch-keeps-missing-records-positional
 : test-cat-file-batch-parses-blob-records-in-order
 : test-cat-file-batch-splits-content-by-size-not-lines
 : test-cat-file-batch-treats-non-blob-objects-as-missing
 : test-name-status-parses-renames-as-renames
 : test-name-status-parses-simple-entry
 : test-name-status-treats-copies-as-rename-entries
 : test-no-index-folder-to-file-diffs-against-the-file
 : test-no-index-ignores-lines-that-are-not-name-status
 : test-no-index-keeps-single-file-comparison-entry
 : test-no-index-parses-folder-comparison-lines
 : test-numstat-collects-totals-and-file-stats
 : test-numstat-indexes-braced-rename-target
 : test-working-marks-entries-absent-from-staged-set-as-unstaged
 : test-working-keeps-real-kind-for-staged-rename
 : test-path-set-collects-lines}
