(local faith (require :faith))
(local preview-key (require :preview.key))
(local plan (require :preview.warm_plan))

(fn entry [status path ?old-path]
  {:status status :kind (status:sub 1 1) :path path :old_path ?old-path})

(fn paths [entries]
  (icollect [_ entry (ipairs entries)]
    entry.path))

(fn test-missing-entries-skips-cached-previews []
  (let [first (entry "M" "a.rb")
        second (entry "M" "b.rb")
        first-key (preview-key.for-entry "HEAD" first)
        cache {first-key ["cached"]}]
    (faith.= [second] (plan.missing-entries "HEAD" [first second] cache))
    (faith.= [first second] (plan.missing-entries "HEAD" [first second] nil))))

(fn test-side-priority-entries-warmer-from-edges-to-center []
  (let [entries (fcollect [i 1 20]
                  (entry "M" (tostring i)))]
    (faith.= ["1"
              "2"
              "3"
              "4"
              "5"
              "6"
              "7"
              "8"
              "20"
              "19"
              "18"
              "17"
              "16"
              "15"
              "14"
              "13"
              "9"
              "10"
              "11"
              "12"] (paths (plan.side-priority-entries entries)))))

(fn test-side-priority-entries-handles-small-lists []
  (let [entries (fcollect [i 1 6]
                  (entry "M" (tostring i)))]
    (faith.= ["1" "2" "3" "4" "5" "6"]
             (paths (plan.side-priority-entries entries)))))

(fn test-index-entries-builds_bidirectional_key_maps []
  (let [first (entry "M" "a.rb")
        second (entry "R" "new.rb" "old.rb")
        (key-index index-key) (plan.index-entries "HEAD" [first second])
        first-key (preview-key.for-entry "HEAD" first)
        second-key (preview-key.for-entry "HEAD" second)]
    (faith.= 1 (. key-index first-key))
    (faith.= 2 (. key-index second-key))
    (faith.= first-key (. index-key 1))
    (faith.= second-key (. index-key 2))))

{: test-index-entries-builds_bidirectional_key_maps
 : test-missing-entries-skips-cached-previews
 : test-side-priority-entries-handles-small-lists
 : test-side-priority-entries-warmer-from-edges-to-center}
