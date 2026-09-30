(local faith (require :faith))
(local fennel-command (require :platform.fennel))
(local preview-key (require :preview.key))
(local preview-warm (require :preview.warm))
(local sys (require :platform.core))
(local t (require :test-helper))

(fn write-output [dir index lines ?split]
  (faith.is (sys.write-data-file (.. dir "/" index ".lua")
                                 {: lines :split ?split})))

(fn entry [status path ?old-path]
  {: status :kind (status:sub 1 1) : path :old_path ?old-path})

(fn paths [entries]
  (icollect [_ entry (ipairs entries)]
    entry.path))

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
     : key-index
     : index-key}))

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
    (preview-warm.update state {:lines cache})
    (faith.= ["first"] (. cache first-key))
    (faith.= ["second"] (. cache second-key))
    (faith.= nil state.dir)
    (faith.= false (sys.write-file "warm/still-there" "x"))))

(fn test-update-imports-split-rows-into-split-cache []
  (t.reset-workdir)
  (t.mkdir "warm")
  (t.write-file "warm/manifest.fnl" "{}")
  (write-output "warm" 1 ["unified"] [{:kind :change :old "a" :new "b"}])
  (let [first (entry "M" "a.rb")
        first-key (preview-key.for-entry "HEAD" first)
        state (warm-state [first])
        cache {}
        split-cache {}]
    (preview-warm.update state {:lines cache :split split-cache})
    (faith.= ["unified"] (. cache first-key))
    (faith.= [{:kind :change :old "a" :new "b"}]
             (. split-cache (.. first-key "\0split")))))

(fn test-update-imports-numbers-refs-and-blame-caches []
  (t.reset-workdir)
  (t.mkdir "warm")
  (t.write-file "warm/manifest.fnl" "{}")
  (faith.is (sys.write-data-file "warm/1.lua"
                                 {:lines ["unified"]
                                  :numbers [false 1]
                                  :refs [false {:side :new :no 1}]
                                  :split []
                                  :blame {"blame-key" {1 "01/01/2024 ann"}}}))
  (let [first (entry "M" "a.rb")
        first-key (preview-key.for-entry "HEAD" first)
        state (warm-state [first])
        caches {:lines {} :split {} :numbers {} :refs {} :blame {}}]
    (preview-warm.update state caches)
    (faith.= ["unified"] (. caches.lines first-key))
    (faith.= [false 1] (. caches.numbers first-key))
    (faith.= [false {:side :new :no 1}] (. caches.refs first-key))
    (faith.= {1 "01/01/2024 ann"} (. caches.blame "blame-key"))))

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
    (preview-warm.update state {:lines cache})
    (faith.= nil (. cache first-key))
    (faith.= ["second"] (. cache second-key))
    (faith.= 1 state.remaining)
    (faith.= "warm" state.dir)
    (write-output "warm" 1 ["first"])
    (preview-warm.update state {:lines cache})
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
    (faith.= nil (preview-warm.import-key state {:lines cache} first-key))
    (faith.= nil (. cache second-key))
    (faith.is (preview-warm.import-key state {:lines cache} second-key))
    (faith.= ["second"] (. cache second-key))
    (faith.= nil (. cache first-key))
    (faith.= 1 state.remaining)))

(fn test-import-key-ignores-keys-the-run-does-not-compute []
  (t.reset-workdir)
  (t.mkdir "warm")
  (let [first (entry "M" "a.rb")
        state (warm-state [first])
        cache {}]
    (write-output "warm" 1 ["plain"])
    (faith.= nil
             (preview-warm.import-key state {:lines cache}
                                      (preview-key.for-entry "HEAD" first true)))
    (faith.= 1 state.remaining)))

(fn test-start-writes-settings-and-keys-entries-with-them []
  (t.reset-workdir)
  (let [first (entry "M" "a.rb")
        settings {:revision "HEAD"
                  :full-context? true
                  :hide-comments? true
                  :blame? true
                  :highlight {:on? true}}
        state (preview-warm.new-state)
        key (preview-key.for-entry "HEAD" first true true true)]
    (preview-warm.start state "/nonexistent-src" [first] settings)
    (faith.= 1 (. state.key-index key))
    (faith.= settings state.settings)
    (faith.= true state.blame?)
    (faith.= [true {:entries [first] : settings}]
             [(sys.read-data-file (.. state.dir "/manifest.lua"))])
    (preview-warm.cleanup state)
    (faith.= nil state.settings)))

(fn test-missing-entries-skips-cached-previews []
  (let [first (entry "M" "a.rb")
        second (entry "M" "b.rb")
        first-key (preview-key.for-entry "HEAD" first)
        cache {first-key ["cached"]}]
    (faith.= [second]
             (preview-warm.missing-entries "HEAD" [first second] cache))
    (faith.= [first second]
             (preview-warm.missing-entries "HEAD" [first second] nil))))

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
              "12"]
             (paths (preview-warm.side-priority-entries entries)))))

(fn test-side-priority-entries-handles-small-lists []
  (let [entries (fcollect [i 1 6]
                  (entry "M" (tostring i)))]
    (faith.= ["1" "2" "3" "4" "5" "6"]
             (paths (preview-warm.side-priority-entries entries)))))

(fn test-start-with-no-missing-entries-cleans-existing-warmer []
  (t.reset-workdir)
  (t.mkdir "warm")
  (t.write-file "warm/manifest.fnl" "{}")
  (let [state (warm-state [(entry "M" "a.rb")])]
    (set state.dir "warm")
    (preview-warm.start state "." [] {:revision "HEAD"})
    (faith.= nil state.dir)
    (faith.= false (sys.write-file "warm/still-there" "x"))))

(fn step-clock []
  (var now 0)
  (fn []
    (set now (+ now 1))
    now))

(fn test-update-imports-ready-previews-within-the-time-budget []
  (t.reset-workdir)
  (t.mkdir "warm")
  (let [entries (fcollect [i 1 10]
                  (entry "M" (.. i ".rb")))
        state (warm-state entries)
        cache {}]
    (for [i 1 10]
      (write-output "warm" i [(.. "file " i)]))
    (preview-warm.update state {:lines cache} {:clock (step-clock) :budget 3})
    (faith.= 7 state.remaining)
    (faith.= 4 state.scan-index)
    (faith.= ["file 3"] (. cache (preview-key.for-entry "HEAD" (. entries 3))))
    (faith.= nil (. cache (preview-key.for-entry "HEAD" (. entries 4))))
    (preview-warm.update state {:lines cache})
    (faith.= nil state.dir)
    (faith.= ["file 10"]
             (. cache (preview-key.for-entry "HEAD" (. entries 10))))))

(fn test-update-imports-one-preview-even-past-the-budget []
  (t.reset-workdir)
  (t.mkdir "warm")
  (let [entries [(entry "M" "a.rb") (entry "M" "b.rb")]
        state (warm-state entries)
        cache {}]
    (write-output "warm" 1 ["first"])
    (write-output "warm" 2 ["second"])
    (preview-warm.update state {:lines cache} {:clock (step-clock) :budget 0})
    (faith.= 1 state.remaining)
    (faith.= ["first"] (. cache (preview-key.for-entry "HEAD" (. entries 1))))))

(fn test-update-drops-unreadable-output-and-finishes-the-run []
  (t.reset-workdir)
  (t.mkdir "warm")
  (t.write-file "warm/1.lua" "return {")
  (write-output "warm" 2 ["second"])
  (let [entries [(entry "M" "a.rb") (entry "M" "b.rb")]
        state (warm-state entries)
        cache {}]
    (faith.= true (preview-warm.update state {:lines cache}))
    (faith.= nil (. cache (preview-key.for-entry "HEAD" (. entries 1))))
    (faith.= ["second"] (. cache (preview-key.for-entry "HEAD" (. entries 2))))
    (faith.= nil state.dir)))

(fn test-store-output-keeps-values-already-cached []
  (let [cached ["cached"]
        caches {:lines {:key cached} :split {} :blame {:b ["old"]}}]
    (preview-warm.store-output caches :key
                               {:lines ["new"]
                                :split [{:kind :context}]
                                :blame {:b ["new"] :c ["c"]}})
    (faith.is (= cached (. caches.lines :key)))
    (faith.= [{:kind :context}] (. caches.split "key\0split"))
    (faith.= {:b ["old"] :c ["c"]} caches.blame)))

(fn test-worker-command-loads-runtime-and-macro-paths []
  (let [command (preview-warm.worker-command "/app/src" "manifest.fnl" "warm" 1
                                             4)]
    (faith.match "%-%-add%-fennel%-path '/app/src/%?%.fnl'" command)
    (faith.match "%-%-add%-macro%-path '/app/src/%?%.fnlm;/app/src/%?%.fnl'"
                 command)
    (faith.match "'/app/src/preview/worker%.fnl'" command)
    (faith.match "^nice %-n 10 fennel " command)))

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
 : test-import-key-ignores-keys-the-run-does-not-compute
 : test-start-writes-settings-and-keys-entries-with-them
 : test-import-entry-checks-only-the-requested-ready-preview
 : test-update-imports-numbers-refs-and-blame-caches
 : test-missing-entries-skips-cached-previews
 : test-side-priority-entries-handles-small-lists
 : test-side-priority-entries-warmer-from-edges-to-center
 : test-start-with-no-missing-entries-cleans-existing-warmer
 : test-update-imports-all-previews-and-cleans-temp-dir
 : test-store-output-keeps-values-already-cached
 : test-update-drops-unreadable-output-and-finishes-the-run
 : test-update-imports-one-preview-even-past-the-budget
 : test-update-imports-ready-previews-within-the-time-budget
 : test-update-imports-split-rows-into-split-cache
 : test-update-imports-ready-previews-out-of-order
 : test-worker-command-loads-runtime-and-macro-paths}
