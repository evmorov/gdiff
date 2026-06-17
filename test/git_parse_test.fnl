(local faith (require :faith))
(local parse (require :git.parse))

(fn first-entry [text]
  (. (parse.parse-name-status text) 1))

(fn test-name-status-parses-simple_entry []
  (faith.= {:kind "M"
            :old_path nil
            :path "src/app.fnl"
            :reviewed false
            :status "M"} (first-entry "M\tsrc/app.fnl\n")))

(fn test-name-status-parses-renames_as_renames []
  (faith.= {:kind "R"
            :old_path "spec/tardis/api_spec.rb"
            :path "spec/tardis/api/v2_spec.rb"
            :reviewed false
            :status "R"}
           (first-entry "R057\tspec/tardis/api_spec.rb\tspec/tardis/api/v2_spec.rb\n")))

(fn test-name-status-treats-copies_as_rename_entries []
  (faith.= {:kind "R"
            :old_path "old.fnl"
            :path "new.fnl"
            :reviewed false
            :status "R"} (first-entry "C057\told.fnl\tnew.fnl\n")))

(fn test-numstat-collects_totals_and_file_stats []
  (let [stats (parse.parse-numstat "2\t1\tsrc/app.fnl\n-\t-\timage.png\n")]
    (faith.= 2 stats.additions)
    (faith.= 1 stats.deletions)
    (faith.= {:additions 2 :deletions 1} (. stats.files "src/app.fnl"))
    (faith.= nil (. stats.files "image.png"))))

(fn test-numstat-indexes_braced_rename_target []
  (let [stats (parse.parse-numstat "1\t0\tspec/tardis/{api_spec.rb => api/v2_spec.rb}\n")]
    (faith.= {:additions 1 :deletions 0}
             (. stats.files "spec/tardis/api/v2_spec.rb"))))

{: test-name-status-parses-renames_as_renames
 : test-name-status-parses-simple_entry
 : test-name-status-treats-copies_as_rename_entries
 : test-numstat-collects_totals_and_file_stats
 : test-numstat-indexes_braced_rename_target}
