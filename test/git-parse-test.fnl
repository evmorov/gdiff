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
            :old_path "spec/tardis/api_spec.rb"
            :path "spec/tardis/api/v2_spec.rb"
            :reviewed false
            :status "R"}
           (first-entry "R057\tspec/tardis/api_spec.rb\tspec/tardis/api/v2_spec.rb\n")))

(fn test-name-status-treats-copies-as-rename-entries []
  (faith.= {:kind "R"
            :old_path "old.fnl"
            :path "new.fnl"
            :reviewed false
            :status "R"} (first-entry "C057\told.fnl\tnew.fnl\n")))

(fn test-numstat-collects-totals-and-file-stats []
  (let [stats (parse.parse-numstat "2\t1\tsrc/app.fnl\n-\t-\timage.png\n")]
    (faith.= 2 stats.additions)
    (faith.= 1 stats.deletions)
    (faith.= 2 stats.code_additions)
    (faith.= 1 stats.code_deletions)
    (faith.= {:additions 2 :deletions 1} (. stats.files "src/app.fnl"))
    (faith.= nil (. stats.files "image.png"))))

(fn test-numstat-code-totals-exclude-markdown []
  (let [stats (parse.parse-numstat "2\t1\tsrc/app.fnl\n5\t3\tREADME.md\n1\t0\tdocs/guide.markdown\n")]
    (faith.= 8 stats.additions)
    (faith.= 4 stats.deletions)
    (faith.= 2 stats.code_additions)
    (faith.= 1 stats.code_deletions)))

(fn test-numstat-code-totals-follow-rename-target []
  (let [stats (parse.parse-numstat "4\t2\t{README.md => src/app.fnl}\n")]
    (faith.= 4 stats.code_additions)
    (faith.= 2 stats.code_deletions)))

(fn test-numstat-indexes-braced-rename-target []
  (let [stats (parse.parse-numstat "1\t0\tspec/tardis/{api_spec.rb => api/v2_spec.rb}\n")]
    (faith.= {:additions 1 :deletions 0}
             (. stats.files "spec/tardis/api/v2_spec.rb"))))

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

{: test-name-status-parses-renames-as-renames
 : test-name-status-parses-simple-entry
 : test-name-status-treats-copies-as-rename-entries
 : test-numstat-code-totals-exclude-markdown
 : test-numstat-code-totals-follow-rename-target
 : test-numstat-collects-totals-and-file-stats
 : test-numstat-indexes-braced-rename-target
 : test-working-marks-entries-absent-from-staged-set-as-unstaged
 : test-working-keeps-real-kind-for-staged-rename
 : test-path-set-collects-lines}
