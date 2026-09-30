(local faith (require :faith))
(local git (require :git.core))
(local focus (require :preview.focus))
(local focus-server (require :preview.focus-server))
(local plan (require :preview.focus-plan))
(local sys (require :platform.core))
(local t (require :test-helper))

(fn wanted [id ?generation]
  {: id :key id :kind :entry :target {:path id} :generation (or ?generation 0)})

(fn caches []
  {:lines {} :listing {} :split {} :numbers {} :refs {} :blame {}})

(fn write-response [dir n response]
  (faith.is (sys.write-data-file (plan.response-path dir n) response)))

(fn test-request-writes-the-slot-once-per-request []
  (t.reset-workdir)
  (let [state (t.focus-state "focus")]
    (faith.is (focus.request state (wanted "a") {:revision "HEAD"}))
    (faith.= {:seq 1
              :id "a"
              :key "a"
              :kind :entry
              :target {:path "a"}
              :generation 0
              :settings {:revision "HEAD"}}
             (t.read-data "focus/request.lua"))
    (faith.= nil (focus.request state (wanted "a") {:revision "HEAD"}))
    (faith.is (focus.request state (wanted "b") {:revision "HEAD"}))
    (faith.= 2 (. (t.read-data "focus/request.lua") :seq))
    (faith.is (focus.request state (wanted "b" 1) {:revision "HEAD"}))))

(fn test-request-does-nothing-without-a-server []
  (t.reset-workdir)
  (let [state (focus.new-state)]
    (faith.= nil (focus.request state (wanted "a") {}))
    (faith.= false (focus.available? state))))

(fn test-update-imports-responses-in-order-until-a-gap []
  (t.reset-workdir)
  (let [state (t.focus-state "focus")
        caches (caches)]
    (write-response "focus" 1 {:key "a"
                               :generation 0
                               :kind :entry
                               :lines ["a"]})
    (write-response "focus" 2
                    {:key "a" :generation 0 :kind :entry :blame {:b ["label"]}})
    (write-response "focus" 4 {:key "c"
                               :generation 0
                               :kind :entry
                               :lines ["c"]})
    (faith.is (focus.update state caches 0))
    (faith.= ["a"] (. caches.lines "a"))
    (faith.= {:b ["label"]} caches.blame)
    (faith.= nil (. caches.lines "c"))
    (faith.= 3 state.next-response)
    (faith.= false (sys.file-exists? (plan.response-path "focus" 1)))
    (write-response "focus" 3 {:key "b"
                               :generation 0
                               :kind :entry
                               :lines ["b"]})
    (faith.is (focus.update state caches 0))
    (faith.= ["b"] (. caches.lines "b"))
    (faith.= ["c"] (. caches.lines "c"))))

(fn test-update-drops-responses-from-an-older-generation []
  (t.reset-workdir)
  (let [state (t.focus-state "focus")
        caches (caches)]
    (write-response "focus" 1 {:key "a"
                               :generation 0
                               :kind :entry
                               :lines ["old"]})
    (faith.= false (focus.update state caches 1))
    (faith.= nil (. caches.lines "a"))
    (faith.= 2 state.next-response)))

(fn test-update-stores-listing-previews-in-the-listing-cache []
  (t.reset-workdir)
  (let [state (t.focus-state "focus")
        caches (caches)]
    (write-response "focus" 1 {:key "listing\0a.txt"
                               :generation 0
                               :kind :listing
                               :lines ["x"]})
    (focus.update state caches 0)
    (faith.= ["x"] (. caches.listing "listing\0a.txt"))
    (faith.= nil (. caches.lines "listing\0a.txt"))))

(fn test-update-gives-up-on-a-server-that-never-starts []
  (t.reset-workdir)
  (let [state (t.focus-state "focus")]
    (set state.pid nil)
    (set state.restarts 1)
    (set state.started-at 0)
    (set state.checked-at 0)
    (focus.update state (caches) 0 {:now 100})
    (faith.= true state.unavailable?)
    (faith.= false (focus.available? state))
    (faith.= false (sys.dir-exists? "focus"))))

(fn test-cleanup-removes-the-server-dir []
  (t.reset-workdir)
  (let [state (t.focus-state "focus")]
    (focus.cleanup state)
    (faith.= nil state.dir)
    (faith.= false (sys.dir-exists? "focus"))))

(fn test-server-command-runs-the-focus-worker []
  (let [command (focus.server-command "/app/src" "/tmp/focus" 42)]
    (faith.match "^fennel " command)
    (faith.match "'/app/src/preview/focus%-worker%.fnl' '/tmp/focus' '42'"
                 command)))

(fn test-claim-waits-one-poll-then-takes-the-request []
  (t.reset-workdir)
  (t.mkdir "focus")
  (faith.is (sys.write-data-file "focus/request.lua" {:seq 4 :key "a"}))
  (faith.= [nil 4] [(focus-server.claim "focus" nil)])
  (faith.= {:seq 4 :key "a"} (focus-server.claim "focus" 4))
  (faith.= false (sys.file-exists? "focus/request.lua"))
  (faith.= false (sys.file-exists? "focus/claimed.lua")))

(fn test-claim-keeps-waiting-when-a-newer-request-arrives []
  (t.reset-workdir)
  (t.mkdir "focus")
  (faith.is (sys.write-data-file "focus/request.lua" {:seq 5 :key "b"}))
  (faith.= [nil 5] [(focus-server.claim "focus" 4)])
  (faith.is (sys.file-exists? "focus/request.lua")))

(fn setup-repo []
  (t.init-repo)
  (t.write-file "app.rb" "one\ntwo\n")
  (t.commit-all "initial")
  (t.write-file "app.rb" "one\ntwo\nthree\n"))

(fn test-handle-sends-lines-first-and-blame-second []
  (setup-repo)
  (let [(entries err) (git.diff-entries "HEAD")
        responses []
        request {:key "k"
                 :generation 3
                 :kind :entry
                 :target (. entries 1)
                 :settings {:revision "HEAD"
                            :old-label "HEAD"
                            :new-label "working tree"
                            :blame? true}}]
    (faith.= nil err)
    (focus-server.run-request request #(table.insert responses $1))
    (faith.= 2 (length responses))
    (let [[first second] responses]
      (faith.= "k" first.key)
      (faith.= 3 first.generation)
      (faith.match "three" (t.text first.lines))
      (faith.= nil first.blame)
      (faith.= nil second.lines)
      (faith.is (next second.blame)))))

(fn test-handle-turns-an-error-into-a-warning-preview []
  (let [responses []]
    (focus-server.run-request {:key "k"
                               :generation 0
                               :kind :entry
                               :target {}
                               :settings {:revision "HEAD"}}
                              #(table.insert responses $1))
    (faith.= 1 (length responses))
    (faith.= "k" (. responses 1 :key))
    (faith.= false (. responses 1 :refs))))

(fn test-handle-renders-listing-rows []
  (t.reset-workdir)
  (t.write-file "notes.txt" "hello\n")
  (let [responses []]
    (focus-server.run-request {:key "listing\0notes.txt"
                               :generation 0
                               :kind :listing
                               :target {:path "notes.txt"}
                               :settings {:revision "HEAD"}}
                              #(table.insert responses $1))
    (faith.match "hello" (t.text (. responses 1 :lines)))))

{: test-claim-keeps-waiting-when-a-newer-request-arrives
 : test-claim-waits-one-poll-then-takes-the-request
 : test-cleanup-removes-the-server-dir
 : test-handle-renders-listing-rows
 : test-handle-sends-lines-first-and-blame-second
 : test-handle-turns-an-error-into-a-warning-preview
 : test-request-does-nothing-without-a-server
 : test-request-writes-the-slot-once-per-request
 : test-server-command-runs-the-focus-worker
 : test-update-drops-responses-from-an-older-generation
 : test-update-gives-up-on-a-server-that-never-starts
 : test-update-imports-responses-in-order-until-a-gap
 : test-update-stores-listing-previews-in-the-listing-cache}
