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

(fn warm-state [entries]
  (let [index-key {}
        key-index {}]
    (each [index entry (ipairs entries)]
      (let [key (preview-key.for-entry "HEAD" entry)]
        (tset index-key index key)
        (tset key-index key index)))
    {:dir "warm"
     :count (length entries)
     :remaining (length entries)
     :scan-index 1
     :imported {}
     :key-index key-index
     :index-key index-key}))

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
        state (warm-state [first second])
        cache {}]
    (preview-warm.update state cache)
    (faith.= ["first"] (. cache first-key))
    (faith.= ["second"] (. cache second-key))
    (faith.= nil state.dir)
    (faith.= false (sys.write-file "warm/still-there" "x"))))

(fn test-update-imports-ready-previews-out-of-order []
  (t.reset-workdir)
  (t.mkdir "warm")
  (write-output "warm" 2 ["second"])
  (let [first (entry "M" "a.rb")
        second (entry "M" "b.rb")
        first-key (preview-key.for-entry "HEAD" first)
        second-key (preview-key.for-entry "HEAD" second)
        state (warm-state [first second])
        cache {}]
    (preview-warm.update state cache)
    (faith.= nil (. cache first-key))
    (faith.= ["second"] (. cache second-key))
    (faith.= 1 state.remaining)
    (faith.= "warm" state.dir)
    (write-output "warm" 1 ["first"])
    (preview-warm.update state cache)
    (faith.= ["first"] (. cache first-key))
    (faith.= nil state.dir)))

(fn test-update-imports-ready-previews-in-small-batches []
  (t.reset-workdir)
  (t.mkdir "warm")
  (let [entries (fcollect [i 1 10]
                  (entry "M" (.. i ".rb")))
        state (warm-state entries)
        cache {}]
    (for [i 1 10]
      (write-output "warm" i [(.. "file " i)]))
    (preview-warm.update state cache)
    (faith.= 2 state.remaining)
    (faith.= 9 state.scan-index)
    (faith.= ["file 1"] (. cache (preview-key.for-entry "HEAD" (. entries 1))))
    (faith.= ["file 8"] (. cache (preview-key.for-entry "HEAD" (. entries 8))))
    (faith.= nil (. cache (preview-key.for-entry "HEAD" (. entries 9))))
    (preview-warm.update state cache)
    (faith.= nil state.dir)
    (faith.= ["file 10"]
             (. cache (preview-key.for-entry "HEAD" (. entries 10))))))

{: test-update-imports-all-previews-and-cleans-temp-dir
 : test-update-imports-ready-previews-in-small-batches
 : test-update-imports-ready-previews-out-of-order}
