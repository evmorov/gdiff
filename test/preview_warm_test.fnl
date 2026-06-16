(local faith (require :faith))
(local fennel (require :fennel))
(local preview-key (require :preview_key))
(local preview-warm (require :preview_warm))
(local sys (require :sys))
(local t (require :test-helper))

(fn write-output [dir index lines]
  (faith.is (sys.write-file (.. dir "/" index ".fnl") (fennel.view lines))))

(fn entry [status path ?old-path]
  {:status status :kind (status:sub 1 1) :path path :old_path ?old-path})

(fn test-update-imports-all-previews-and-cleans-temp-dir []
  (t.reset-workdir)
  (t.mkdir "warm")
  (t.write-file "warm/manifest.fnl" "{}")
  (write-output "warm" 1 ["first"])
  (write-output "warm" 2 ["second"])
  (let [first (entry "M" "a.rb")
        second (entry "R100" "new.rb" "old.rb")
        first-key (preview-key.for-entry "HEAD" first)
        second-key (preview-key.for-entry "HEAD" second)
        state {:dir "warm"
               :next-index 1
               :count 2
               :key-index {first-key 1 second-key 2}
               :index-key {1 first-key 2 second-key}}
        cache {}]
    (preview-warm.update state cache)
    (faith.= ["first"] (. cache first-key))
    (faith.= ["second"] (. cache second-key))
    (faith.= nil state.dir)
    (faith.= false (sys.write-file "warm/still-there" "x"))))

{: test-update-imports-all-previews-and-cleans-temp-dir}
