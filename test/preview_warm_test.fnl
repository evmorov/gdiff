(local faith (require :faith))
(local fennel (require :fennel))
(local fennel-command (require :platform.fennel))
(local preview-key (require :preview.key))
(local preview-warm (require :preview.warm))
(local sys (require :platform.core))
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

(fn test-import-entry-checks-only-the-requested-ready-preview []
  (t.reset-workdir)
  (t.mkdir "warm")
  (let [first (entry "M" "a.rb")
        second (entry "M" "b.rb")
        first-key (preview-key.for-entry "HEAD" first)
        second-key (preview-key.for-entry "HEAD" second)
        state (warm-state [first second])
        cache {}]
    (write-output "warm" 2 ["second"])
    (faith.= nil (preview-warm.import-entry state cache "HEAD" first))
    (faith.= nil (. cache second-key))
    (faith.is (preview-warm.import-entry state cache "HEAD" second))
    (faith.= ["second"] (. cache second-key))
    (faith.= nil (. cache first-key))
    (faith.= 1 state.remaining)))

(fn test-missing-entries-skips-cached-previews []
  (let [first (entry "M" "a.rb")
        second (entry "M" "b.rb")
        first-key (preview-key.for-entry "HEAD" first)
        cache {first-key ["cached"]}]
    (faith.= [second]
             (preview-warm.missing-entries "HEAD" [first second] cache))
    (faith.= [first second]
             (preview-warm.missing-entries "HEAD" [first second] nil))))

(fn test-start-with-no-missing-entries-cleans-existing-warmer []
  (t.reset-workdir)
  (t.mkdir "warm")
  (t.write-file "warm/manifest.fnl" "{}")
  (let [state (warm-state [(entry "M" "a.rb")])]
    (set state.dir "warm")
    (preview-warm.start state "." "HEAD" [])
    (faith.= nil state.dir)
    (faith.= false (sys.write-file "warm/still-there" "x"))))

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

(fn test-worker-command-loads-runtime-and-macro-paths []
  (let [command (preview-warm.worker-command "/app/src" "manifest.fnl" "warm" 1
                                             4)]
    (faith.match "%-%-add%-fennel%-path '/app/src/%?%.fnl'" command)
    (faith.match "%-%-add%-macro%-path '/app/src/%?%.fnlm;/app/src/%?%.fnl'"
                 command)
    (faith.match "'/app/src/preview/worker%.fnl'" command)))

(fn test-fennel-command-builds-standard-subprocess-environment []
  (let [command (fennel-command.command "/app/src" :preview/worker.fnl
                                        ["manifest.fnl" "warm" 1 4])]
    (faith.match "^fennel " command)
    (faith.match "%-%-add%-fennel%-path '/app/src/%?%.fnl'" command)
    (faith.match "%-%-add%-macro%-path '/app/src/%?%.fnlm;/app/src/%?%.fnl'"
                 command)
    (faith.match "'/app/src/preview/worker%.fnl' 'manifest%.fnl' 'warm' '1' '4'"
                 command)))

{: test-fennel-command-builds-standard-subprocess-environment
 : test-import-entry-checks-only-the-requested-ready-preview
 : test-missing-entries-skips-cached-previews
 : test-start-with-no-missing-entries-cleans-existing-warmer
 : test-update-imports-all-previews-and-cleans-temp-dir
 : test-update-imports-ready-previews-in-small-batches
 : test-update-imports-ready-previews-out-of-order
 : test-worker-command-loads-runtime-and-macro-paths}
